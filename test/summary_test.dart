import 'dart:io';
import 'dart:typed_data';

import 'package:run_log/stats/run_data.dart';
import 'package:run_log/summary/summary.dart';
import 'package:test/test.dart';

void main() {
  test('json empty (de)serialization', () {
    var empty = SummaryContainer.empty();
    var emptyStr = empty.toJson();
    var emptyNew = SummaryContainer.fromJson(emptyStr);
    expect(empty, emptyNew);
  });

  test('json filled (de)serialization', () {
    var some = SummaryContainer(
      Uint8List.fromList([1, 2, 3]),
      [4, 5, 6],
      ListPoints.fromDynamicList([
        [0.0, 0.0],
        [0.1, 0.0],
        [0.1, 0.1],
      ]),
      ["Marathon", "2025"],
    );
    var someString = some.toJson();
    var someNew = SummaryContainer.fromJson(someString);
    expect(some, someNew);
  });

  test('create summary from run', () async {
    var runDatas = [
      readLog(0, 'test/logs/run1.gpx'),
      readLog(1, 'test/logs/run2.gpx'),
      readLog(2, 'test/logs/run3.gpx'),
      readLog(3, 'test/logs/run4.gpx'),
    ];
    // Check that the last run is actually much further from the other three
    // runs:
    var runs = runDatas.map((rd) => rd.$1).toList();
    var closest = runDatas.map((rd) => rd.$1.summary?.closest(runs)).toList();
    for (var c in closest.sublist(0, 3).indexed) {
      // Closest run must be ourself
      expect(c.$1, c.$2?.first.$1);
      // Most different run is the last one
      expect(c.$2?.last.$1, 3);
      // Euclidian distance of the last run is higher than the previous runs
      expect(c.$2!.last.$1 > c.$2![2].$1, true);
      for (var d in closest.last!.sublist(1)) {
        // The euclidian distances of the last run to the others must be
        // higher than the 3 first runs between themselves.
        expect(d.$2 > c.$2![1].$2, true);
        expect(d.$2 > c.$2![2].$2, true);
      }
    }
  });
}

(Run, List<TrackedData>) readLog(int id, String name) {
  var data = GpxIO.fromGPX(id, File(name).readAsStringSync());
  var run = Run.now(id);
  run.summary = SummaryContainer.fromData(data);
  return (run, data);
}
