import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:run_log/backup.dart';
import 'package:run_log/storage.dart';

class FakePathProvider extends PathProviderPlatform {
  final String docsPath;

  FakePathProvider(this.docsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<RunStorage> freshStorage(String dbName) async {
    RunStorage.dbName = dbName;
    await databaseFactory.deleteDatabase(await RunStorage.dbPath());
    return RunStorage.initClean();
  }

  Future<void> prefillRuns(RunStorage rs, int count) async {
    for (int i = 0; i < count; i++) {
      await DebugStorage.dbPrefill(
        rs,
        Duration(hours: i + 1),
        5,
        [4, .2, .1, .4, .1, .2],
        [2000, 20, 10, 20, 10],
        null,
      );
    }
  }

  Future<void> writeFakeSnapshot(String fileName) async {
    final dir = await AppBackup.snapshotDir();
    final file = File(join(dir, fileName));
    await file.writeAsString('fake');
  }

  test('Sanity gate: refuses to snapshot an empty DB over a real one', () async {
    final rs = await freshStorage('backup_sanity.db');
    await prefillRuns(rs, 3);

    final firstPath = await AppBackup.createSnapshot(rs.db, force: true);
    expect(firstPath, isNotNull);

    // Wipe the live DB down to 0 runs, then try to snapshot again.
    await rs.cleanDB();
    final secondPath = await AppBackup.createSnapshot(rs.db, force: true);
    expect(secondPath, isNull);

    final snaps = await AppBackup.listSnapshots();
    expect(snaps.length, 1);
    expect(snaps.first.runCount, 3);
  });

  test('Daily gate: two launches same day make one snapshot; force makes two', () async {
    final rs = await freshStorage('backup_daily.db');
    await prefillRuns(rs, 2);

    final first = await AppBackup.createSnapshot(rs.db, force: false);
    expect(first, isNotNull);

    final second = await AppBackup.createSnapshot(rs.db, force: false);
    expect(second, isNull);

    final third = await AppBackup.createSnapshot(rs.db, force: true);
    expect(third, isNotNull);

    final snaps = await AppBackup.listSnapshots();
    expect(snaps.length, 2);
  });

  test(
    'Retention: keeps 5, protects the biggest (newest tiebreak), ignores unparseable names',
    () async {
      final rs = await freshStorage('backup_retention.db');
      await prefillRuns(rs, 1);

      // Manually place 8 parseable snapshot files with controlled run counts
      // and timestamps, so we don't depend on daily-gate timing.
      final counts = [10, 20, 30, 20, 5, 3, 2, 1];
      for (int i = 0; i < counts.length; i++) {
        final ts = DateTime(2026, 1, i + 1, 7, 30);
        final fname =
            "running_log-${ts.year}-${ts.month.toString().padLeft(2, '0')}-"
            "${ts.day.toString().padLeft(2, '0')}-073000-r${counts[i]}.db";
        await writeFakeSnapshot(fname);
      }
      // Stray files that must be neither counted nor deleted by prune.
      await writeFakeSnapshot('running_log-2026-01-01-073000-r10.db.tmp');
      await writeFakeSnapshot('hand-named-backup.db');

      await AppBackup.prune();

      final snaps = await AppBackup.listSnapshots();
      // Biggest count is 30 (day 3); it must survive regardless of age.
      expect(snaps.any((s) => s.runCount == 30), true);
      expect(snaps.length, 5);

      final dir = Directory(await AppBackup.snapshotDir());
      final allFiles = await dir.list().map((e) => basename(e.path)).toList();
      expect(
        allFiles.contains('running_log-2026-01-01-073000-r10.db.tmp'),
        true,
      );
      expect(allFiles.contains('hand-named-backup.db'), true);
    },
  );

  test(
    'Retention tie case: two snapshots share the top count, newest wins',
    () async {
      RunStorage.dbName = 'backup_tie.db';
      await databaseFactory.deleteDatabase(await RunStorage.dbPath());

      await writeFakeSnapshot("running_log-2026-01-01-073000-r50.db");
      await writeFakeSnapshot("running_log-2026-01-05-073000-r50.db");
      for (int i = 2; i <= 5; i++) {
        await writeFakeSnapshot(
          "running_log-2026-01-0$i-073100-r${10 + i}.db",
        );
      }

      await AppBackup.prune();

      final snaps = await AppBackup.listSnapshots();
      expect(
        snaps.any(
          (s) => s.fileName == "running_log-2026-01-05-073000-r50.db",
        ),
        true,
      );
      expect(
        snaps.any(
          (s) => s.fileName == "running_log-2026-01-01-073000-r50.db",
        ),
        false,
      );
    },
  );

  test(
    'Restore round-trip: data matches, safety snapshot taken, cache invalidated',
    () async {
      final rs = await freshStorage('backup_restore.db');
      await prefillRuns(rs, 2);
      final runIds = rs.runs.keys.toList()..sort();

      // Warm the trackedData cache for run 1 before snapshotting.
      final originalTrack = await rs.loadTrackedData(runIds[0]);
      expect(originalTrack.length, 5);

      final snapPath = await AppBackup.createSnapshot(rs.db, force: true);
      expect(snapPath, isNotNull);
      final snaps = await AppBackup.listSnapshots();
      final snap = snaps.firstWhere((s) => s.path == snapPath);

      // Mutate the live DB: remove a run, and change the cached run's track
      // by adding a point directly, so we can tell restored data apart from
      // whatever is currently cached in memory.
      await rs.removeRun(runIds[1]);
      await rs.db.insert('TrackedData', {
        'run_id': runIds[0],
        'timestamp': 999999999,
        'latitude': 1.0,
        'longitude': 1.0,
        'altitude': 1.0,
        'gps_accuracy': 5.0,
      });
      // Re-warm the cache with the mutated (6-point) track.
      rs.trackedData.remove(runIds[0]);
      final mutatedTrack = await rs.loadTrackedData(runIds[0]);
      expect(mutatedTrack.length, 6);

      final snapshotsBeforeRestore = (await AppBackup.listSnapshots()).length;

      await AppBackup.restore(rs, snap);

      // A safety snapshot of the pre-restore state must have been taken.
      final snapshotsAfterRestore = (await AppBackup.listSnapshots()).length;
      expect(snapshotsAfterRestore, greaterThan(snapshotsBeforeRestore));

      // Restored data must match what was snapshotted, not the mutated state.
      expect(rs.runs.length, 2);
      expect(rs.runs.containsKey(runIds[1]), true);

      // Cache must be invalidated: this must return the restored (5-point)
      // track, not the stale cached 6-point mutated track.
      final restoredTrack = await rs.loadTrackedData(runIds[0]);
      expect(restoredTrack.length, 5);
    },
  );
}
