import 'package:geolocator/geolocator.dart';
import 'package:run_log/feedback/tones.dart';
import 'package:run_log/stats/conversions.dart';
import 'package:test/test.dart';

import 'package:run_log/stats/run_data.dart';
import 'package:run_log/stats/run_stats.dart';

void main() {
  test('Test updating altitudeCorrected', () {
    // Create RunStats with some simple values
    // Check slopes
    // Update altitudeCorrected with updateSlopes
    // Check new slopes
    // Border cases:
    // - index == 0, index > 0
    // - check previous runningData stays untouched
    // - check updates are done in the correct runningData
    // - check if too many update points are given
    // - check that pauses are not handled too badly
    //   (not too important, we might get away with ignoring those).
  });
}