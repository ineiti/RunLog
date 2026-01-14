import 'package:flutter_test/flutter_test.dart';
import 'package:run_log/feedback/feedback.dart';
import 'package:run_log/feedback/tones.dart';
import 'package:run_log/stats/run_data.dart';
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
      [1],
      SFEntry.fromPoints([
        SpeedPoint(distanceM: 0, speedMS: 3),
        SpeedPoint(distanceM: 1000, speedMS: 4),
      ]),
    );
    await checkFeedback(feedback);
    feedback = FeedbackContainer(FeedbackType.slope, [1], feedback.target);
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

  test('Store and get FeedbackContainer', () async {
    final feedback = FeedbackContainer(
      FeedbackType.pace,
      [1],
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
