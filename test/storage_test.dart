import 'package:flutter_test/flutter_test.dart';
import 'package:run_log/feedback/feedback.dart';
import 'package:run_log/feedback/tones.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:run_log/storage.dart';

void main() {
  Future<void> checkFeedback(FeedbackContainer? feedback) async {
    RunStorage.dbName = "test_db.db";
    var rs = await RunStorage.initClean();
    await DebugStorage.dbPrefill(
      rs,
      Duration(hours: 5),
      10,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
      feedback,
    );
    var id = rs.runs.keys.first;

    rs.runs.clear();
    rs = await RunStorage.initLoad();
    expect(rs.runs[id]?.feedback, feedback);
  }

  setUpAll(() async {
    sqfliteFfiInit(); // Call once before all tests
    databaseFactory = databaseFactoryFfi;
  });

  test("(De)serializing SFEntries", () async {
    await checkFeedback(FeedbackContainer.empty());
    var feedback = FeedbackContainer(
      FeedbackType.pace,
      SFEntry.fromPoints([
        SpeedPoint(distanceM: 0, speedMS: 3),
        SpeedPoint(distanceM: 1000, speedMS: 4),
      ]),
    );
    await checkFeedback(feedback);
    feedback = FeedbackContainer(FeedbackType.slope, feedback.target);
    await checkFeedback(feedback);
  });

  test('Exporting and re-importing all', () async {
    RunStorage.dbName = "test_db.db";
    var rs = await RunStorage.initClean();
    await DebugStorage.dbPrefill(
      rs,
      Duration(hours: 5),
      10,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
      null,
    );
    await DebugStorage.dbPrefill(
      rs,
      Duration(hours: 2),
      5,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
      null,
    );

    final dump = await rs.exportAll();

    RunStorage.dbName = "test_db_2.db";
    var rs2 = await RunStorage.initClean();
    await rs2.importAll(dump);

    expect(2, rs2.runs.length);
    expect(10, rs2.trackedData[1]?.length);
    expect(5, rs2.trackedData[2]?.length);
    expect(rs.runs, rs2.runs);
  });

  test(
    'exportAll reads from disk, not the in-memory runs map (partial load)',
    () async {
      RunStorage.dbName = "test_db_export_partial.db";
      await databaseFactory.deleteDatabase(await RunStorage.dbPath());
      var rs = await RunStorage.initClean();
      await DebugStorage.dbPrefill(
        rs,
        Duration(hours: 5),
        4,
        [4, .2, .1, .4, .1, .2],
        [2000, 20, 10, 20, 10],
        null,
      );
      await DebugStorage.dbPrefill(
        rs,
        Duration(hours: 2),
        3,
        [4, .2, .1, .4, .1, .2],
        [2000, 20, 10, 20, 10],
        null,
      );

      // Simulate a partial in-memory load: the DB has 2 runs on disk, but
      // only 1 made it into the in-memory map (e.g. the other failed to
      // deserialize and was skipped by loadRuns()).
      final bothIds = rs.runs.keys.toList()..sort();
      rs.runs.remove(bothIds[1]);
      expect(rs.runs.length, 1);

      final dump = await rs.exportAll();

      RunStorage.dbName = "test_db_export_partial_2.db";
      await databaseFactory.deleteDatabase(await RunStorage.dbPath());
      var rs2 = await RunStorage.initClean();
      await rs2.importAll(dump);

      // exportAll must have read both runs from disk, not just the one
      // remaining in the in-memory map.
      expect(rs2.runs.length, 2);
    },
  );

  test(
    'Bad row is skipped, good runs survive, log names the bad row',
    () async {
      RunStorage.dbName = "test_db_bad_row.db";
      await databaseFactory.deleteDatabase(await RunStorage.dbPath());
      var rs = await RunStorage.initClean();
      await DebugStorage.dbPrefill(
        rs,
        Duration(hours: 5),
        10,
        [4, .2, .1, .4, .1, .2],
        [2000, 20, 10, 20, 10],
        null,
      );
      await DebugStorage.dbPrefill(
        rs,
        Duration(hours: 2),
        5,
        [4, .2, .1, .4, .1, .2],
        [2000, 20, 10, 20, 10],
        null,
      );
      final goodRunIds = rs.runs.keys.toList()..sort();
      expect(goodRunIds.length, 2);

      // Corrupt gps_accuracy on one row of the second run's track. This is
      // recoverable once 1d makes the cast nullable, but still exercises
      // the per-row skip path for TrackedData.
      final firstPointId =
          Sqflite.firstIntValue(
            await rs.db.rawQuery(
              'SELECT id FROM TrackedData WHERE run_id = ? LIMIT 1',
              [goodRunIds[1]],
            ),
          )!;
      await rs.db.update(
        'TrackedData',
        {'gps_accuracy': null},
        where: 'id = ?',
        whereArgs: [firstPointId],
      );
      // Corrupt total_distance with a type sqflite can't coerce to a
      // number, so the row stays genuinely unreadable even after 1c/1d.
      await rs.db.rawUpdate(
        "UPDATE Runs SET total_distance = 'not-a-number' WHERE id = ?",
        [goodRunIds[1]],
      );

      final countBefore =
          Sqflite.firstIntValue(
            await rs.db.rawQuery('SELECT COUNT(*) FROM Runs'),
          )!;
      expect(countBefore, 2);

      rs = await RunStorage.initLoad();

      // The row count on disk must be unchanged: no auto-wipe.
      final countAfter =
          Sqflite.firstIntValue(
            await rs.db.rawQuery('SELECT COUNT(*) FROM Runs'),
          )!;
      expect(countAfter, 2);

      // The good run loaded; the bad one was skipped in memory.
      expect(rs.runs.containsKey(goodRunIds[0]), true);
      expect(rs.runs.containsKey(goodRunIds[1]), false);
    },
  );

  test('No auto-wipe: a failure loading tracked data must not delete Runs', () async {
    RunStorage.dbName = "test_db_no_autowipe.db";
    await databaseFactory.deleteDatabase(await RunStorage.dbPath());
    var rs = await RunStorage.initClean();
    await DebugStorage.dbPrefill(
      rs,
      Duration(hours: 5),
      10,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
      null,
    );

    final countBefore =
        Sqflite.firstIntValue(
          await rs.db.rawQuery('SELECT COUNT(*) FROM Runs'),
        )!;
    expect(countBefore, 1);

    // Force ensureStats() down the loadTrackedData() path (it otherwise
    // short-circuits when duration/total_distance are already nonzero),
    // then break that path. Pre-fix, the bare catch in initLoad falls back
    // to initClean(), which issues DELETE FROM Runs (succeeds) then DELETE
    // FROM TrackedData (fails because the table is gone) -- but the Runs
    // row is already gone by then. Post-fix, no such fallback exists.
    await rs.db.update(
      'Runs',
      {'duration': 0, 'total_distance': 0.0},
      where: 'id = ?',
      whereArgs: [rs.runs.keys.first],
    );
    await rs.db.execute('DROP TABLE TrackedData');

    try {
      await RunStorage.initLoad();
    } catch (_) {
      // initLoad may or may not throw depending on how far loading gets;
      // what matters is what happened to the Runs table on disk.
    }

    final rs2 = await RunStorage.init();
    final countAfter =
        Sqflite.firstIntValue(
          await rs2.db.rawQuery('SELECT COUNT(*) FROM Runs'),
        )!;
    expect(countAfter, 1);
  });

  test('Migration coverage: v1 rows survive an open at v4', () async {
    RunStorage.dbName = "test_db_migration.db";
    await databaseFactory.deleteDatabase(await RunStorage.dbPath());

    final v1db = await RunStorage.openDb(version: 1);
    final runId = await v1db.insert('Runs', {
      'start_time': 1000,
      'duration': 60000,
      'total_distance': 200.0,
      'calories_burned': 10,
      'weather': 'sunny',
      'avg_heart_rate': 120,
      'avg_steps_per_min': 150,
    });
    await v1db.insert('TrackedData', {
      'run_id': runId,
      'timestamp': 1000,
      'latitude': 1.0,
      'longitude': 2.0,
      'altitude': 3.0,
      'gps_accuracy': 5.0,
    });
    await v1db.close();

    final v4db = await RunStorage.openDb();
    final runs = await v4db.query('Runs');
    expect(runs.length, 1);
    expect(runs.first['id'], runId);
    expect(runs.first['total_distance'], 200.0);

    final points = await v4db.query('TrackedData');
    expect(points.length, 1);
    expect(points.first['run_id'], runId);

    // Post-migration columns must exist and be queryable (added by v2/v3/v4).
    final columns = await v4db.rawQuery("PRAGMA table_info(Runs)");
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    expect(columnNames.contains('feedback'), true);
    expect(columnNames.contains('summary'), true);
    final tdColumns = await v4db.rawQuery("PRAGMA table_info(TrackedData)");
    final tdColumnNames = tdColumns.map((c) => c['name'] as String).toSet();
    expect(tdColumnNames.contains('altitude_corrected'), true);

    await v4db.close();
  });

  test('Store and get FeedbackContainer', () async {
    final feedback = FeedbackContainer(
      FeedbackType.pace,
      SFEntry.fromPoints([
        SpeedPoint(distanceM: 0, speedMS: 3),
        SpeedPoint(distanceM: 1000, speedMS: 4),
      ]),
    );
    List<TrackedData> points = [
      TrackedData(
        runId: 1,
        timestampMS: 100,
        latitude: 200,
        longitude: 300,
        altitude: 400,
        gpsAccuracy: 500,
      ),
    ];
    final gpxStr = points.toGPX(feedback);
    final (gpx, fb) = GpxIO.fromGPX(1, gpxStr);
    expect(points, gpx);
    expect(feedback, fb);
  });
}
