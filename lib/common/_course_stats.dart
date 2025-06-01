import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:run_log/stats/run_data.dart';

class TimeData implements Comparable<TimeData> {
  TimeData(this.dt, this.mps);

  final double dt;
  final double mps;

  @override
  int compareTo(TimeData other) {
    throw mps.compareTo(other.mps);
  }
}

extension DebugPrint on List<TimeData> {
  /// Prints each element with its index (for debugging)
  String debug() {
    if (isEmpty) {
      return 'List is empty';
    }
    return map(
      (td) => "(${td.dt.toStringAsFixed(1)}, ${td.mps.toStringAsFixed(1)})",
    ).join(", ");
  }
}

class CourseStats {
  // We suppose that positionsFiltered is sampled evenly (TODO).
  // For two positions P0 and P1 with
  // - dt = P0.duration(P1)
  // - s = P0.speed(P1)
  // The following point(s) are/is inserted:
  // - pause + run: (dt, s)
  // - run + run: (dt, s)
  // - run + pause: nothing
  // - pause + pause: (0, 0)
  // Then it is calculated from the previous by splitting it
  // at positions where (speed == 0).
  // Every segment is then filtered using lanczos, and gets the following
  // points:
  // - beginning: (0, s), (dt/2, s)
  // - all following points: (dt, s)
  // - ending: (dt, s), (dt/2, s)
  // This ensures that the area under the speed curve equals the distance
  // run. Supposing that "pause" means "stops".
  List<TimeData> speedChart = [];
  double speedMin = 1000;
  double speedMax = 0;
  double distance = 0;
  List<double> lanczos = _lanczos(5);

  double distanceM() {
    return distance;
  }

  double durationS() {
    return speedChart.last.dt;
  }

  CourseStats(List<PositionPause> positions) {
    double totalDuration = 0;
    List<double> durations = [0];
    List<double> speeds = filterValues(
      positions
          .windowMap((pos0, pos1) {
            if (pos1.ppState == PPState.endPause) {
              return -1.0;
            } else {
              final dt = pos1.durationS(pos0);
              final speed = pos0.speedMS(pos1);
              totalDuration += dt;
              if (speed < speedMin) {
                speedMin = speed;
              }
              if (speed > speedMax) {
                speedMax = speed;
              }
              durations.add(totalDuration);
              return speed;
            }
          })
          .where((s) => s > 0)
          .toList(),
    );
    // Double the very first element to make a nice graph which starts at
    // t=0 with speed at t=dt.
    speeds.insert(0, speeds.first);

    speedChart = List.generate(
      speeds.length,
      (i) => TimeData(durations[i], speeds[i]),
    );
  }

  // Applies the lanczos filter to 'values' and keeps the peak at 'pos'.
  // If the lanczos filter doesn't fit, it will be cut and thus not return
  // a nice sampling window.
  double applyLanczos(List<double> values, int pos) {
    if (pos < 0 || pos >= values.length) {
      throw ("pos out of range");
    }
    // This works because lanczos.length is always an odd number.
    int valuesStart = pos - lanczos.length ~/ 2;
    int valuesEnd = pos + lanczos.length ~/ 2;
    int lanczosStart = 0;
    int lanczosEnd = lanczos.length - 1;
    if (valuesStart < 0) {
      lanczosStart -= valuesStart;
      valuesStart = 0;
    }
    if (valuesEnd >= values.length) {
      final overflow = valuesEnd - values.length + 1;
      lanczosEnd -= overflow;
      valuesEnd -= overflow;
    }

    final filter = lanczos.sublist(lanczosStart, lanczosEnd + 1);
    final src = values.sublist(valuesStart, valuesEnd + 1);

    double sum = filter.fold(0.0, (a, b) => a + b);
    return src.asMap().entries.fold(
      0.0,
      (a, b) => a + b.value * filter[b.key] / sum,
    );
  }

  List<double> filterValues(List<double> values) {
    return List.generate(values.length, (i) => applyLanczos(values, i));
  }

  String spChDebug(List<(double, double)> sc) {
    return sc.map((a) => _tSpDebug(a.$1, a.$2)).toString();
  }

  static String _tSpDebug(double dt, double speed) {
    return "(${dt.toStringAsFixed(1)}, ${speed.toStringAsFixed(2)})";
  }

  static List<double> _lanczos(int n2) {
    return List.generate(n2 * 2 + 1, (n) => _sinc(2 * n / (2 * n2) - 1));
  }

  static double _sinc(double x) {
    if (x == 0) {
      return 1;
    }
    x *= pi;
    return sin(x) / x;
  }
}

enum PPState { beginPause, endPause, running }

class PositionPause extends Position {
  final PPState ppState;

  PositionPause(Position pos, this.ppState)
    : super(
        longitude: pos.longitude,
        latitude: pos.latitude,
        timestamp: pos.timestamp,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        altitudeAccuracy: pos.altitudeAccuracy,
        heading: pos.heading,
        headingAccuracy: pos.headingAccuracy,
        speed: pos.speed,
        speedAccuracy: pos.speedAccuracy,
        floor: pos.floor,
        isMocked: pos.isMocked,
      );

  double distanceM(Position other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  double durationS(Position other) {
    return timestamp.difference(other.timestamp).inMilliseconds.abs() / 1000;
  }

  double speedMS(Position after) {
    return distanceM(after) / durationS(after);
  }
}

extension WindowMap<T> on List<T> {
  /// Creates a new list by applying [transform] to each consecutive pair of elements.
  /// Example: [1, 2, 3, 4] → transform(1,2), transform(2,3), transform(3,4)
  List<R> windowMap<R>(R Function(T current, T next) transform) {
    if (length < 2) return [];

    return List.generate(length - 1, (i) => transform(this[i], this[i + 1]));
  }
}

extension SplitAtExtension<T> on List<T> {
  /// Splits the list into sublists whenever [condition] is `true` for an element.
  /// The elements satisfying the condition are **omitted** from the result.
  ///
  /// Example:
  /// ```dart
  /// [1, 2, -1, 3, 4].splitAt((x) => x < 0) → [[1, 2], [3, 4]]
  /// ```
  List<List<T>> splitAt(bool Function(T) condition) {
    return fold<List<List<T>>>([[]], (result, item) {
      if (condition(item)) {
        result.add([]); // Split here (drop item)
      } else {
        result.last.add(item); // Keep item in current sublist
      }
      return result;
    });
  }
}
