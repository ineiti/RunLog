import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

enum PTState { waitAccurateGPS, waitRunning, positionUpdate, paused }

class PositionTracker {
  // If the speed between two GPS measurements drops below pauseSpeed [m/s],
  // a pause is registered.
  // TODO: could register pauses only once more than 'n' samples drop below
  // [pauseSpeed], but then take all samples which are below [pauseSpeed].
  double pauseSpeed = 1.75;

  // Recording starts once the position accuracy is below 'accuracyMin'.
  double accuracyMin = 10;

  // Holds all positions starting from the moment the GPS accuracy is below
  // [accuracyMin].
  List<Position> positionsRaw = [];

  // Always starts with a 'paused' position, followed by an unpaused position.
  // All following 'paused' positions come in pairs and
  // indicate the start and end of the pause:
  // For the following list of filtered positions:
  // [(t0, (p0, false)), (t1, (p1, true)), (t2, (p2, true)), (t3, (p3, false))]
  // - t0 is the last position where the device moved faster than 'pauseSpeed'
  // - t1 is the first position where the device moved slower than 'pauseSpeed'
  // - t2 is the last position where the device moved slower than pauseSpeed
  // - speed(t2, t3) is faster than 'pauseSpeed'
  // - (t1 - t0) <= (t2 - t1) >= (t3 - t2) if the positionRaw events are in regular intervals.
  List<PositionPause> positionsFiltered = [];

  // Speeds calculated from [positionsFiltered].
  // We suppose that positionsFiltered is sampled evenly (TODO).
  // For two positions P0 and P1 with
  // - dt = P0.duration(P1)
  // - s = P0.speed(P1)
  // The following point(s) are/is inserted:
  // - pause + run: (dt, s)
  // - run + run: (dt, s)
  // - run + pause: nothing
  // - pause + pause: (0, 0)
  List<(double, double)> speedChartRaw = [(0, 0)];

  // [speedChart] is calculated from [speedChartRaw] by splitting it
  // at positions where (speed == 0).
  // Every segment is then filtered using lanczos, and gets the following
  // points:
  // - beginning: (0, s), (dt/2, s)
  // - all following points: (dt, s)
  // - ending: (dt, s), (dt/2, s)
  // This ensures that the area under the speed curve equals the distance
  // run. Supposing that "pause" means "stops".
  // TODO: simplify by only calculating last segment after splitting.
  List<(double, double)> speedChart = [(0, 0)];
  late double distance;
  List<double> lanczos = [];

  StreamController<PTState> ptStateStream = StreamController();
  late StreamSubscription<Position> _waitAccuracy;

  static PositionTracker testPT(Position pos) {
    var pt = PositionTracker(StreamController<Position>().stream);
    pt.positionsRaw = [pos];
    pt.positionsFiltered = [PositionPause(pos, PPState.endPause)];
    return pt;
  }

  PositionTracker(Stream<Position> pStream) {
    lanczos = _lanczos(5);
    distance = 0;
    ptStateStream.add(PTState.waitAccurateGPS);
    _waitAccuracy = pStream.listen((Position? position) {
      print("Waiting for accuracy: $position / ${position?.accuracy}");
      if (position != null) {
        if (position.accuracy < 10) {
          _waitAccuracy.cancel();
          positionsRaw = [position];
          positionsFiltered = [PositionPause(position, PPState.endPause)];
          ptStateStream.add(PTState.waitRunning);
          pStream.listen((Position? position) {
            if (position != null) {
              ptStateStream.add(handleNewPosition(position));
            }
          });
        }
      }
    });
  }

  void reset() {
    positionsRaw = [positionsRaw.last];
    positionsFiltered = [PositionPause(positionsRaw.last, PPState.beginPause)];
    pauseSpeed = 1.75;
    speedChartRaw = [];
    speedChart = [(0, 0)];
    distance = 0;
  }

  PTState handleNewPosition(Position newPos) {
    print("New Position $newPos, $distance");
    positionsRaw.add(newPos);

    final prev = positionsFiltered.last;
    if (prev.speedMS(newPos) < pauseSpeed) {
      switch (prev.ppState) {
        case PPState.running:
          positionsFiltered.add(PositionPause(newPos, PPState.beginPause));
        case PPState.endPause:
          positionsFiltered.removeLast();
        default:
      }
      positionsFiltered.add(PositionPause(newPos, PPState.endPause));
      print("Pausing for speed ${prev.speedMS(newPos)}: $_posFilterDebug");

      return positionsFiltered.length == 1
          ? PTState.waitRunning
          : PTState.paused;
    }

    distance += prev.distanceM(newPos);
    positionsFiltered.add(PositionPause(newPos, PPState.running));
    _updateSpeedChartRaw();
    print("SpeedChartRaw: ${spChDebug(speedChartRaw)}");
    print("SpeedChart: ${spChDebug(speedChart)}");
    return PTState.positionUpdate;
  }

  Stream<PTState> get stream => ptStateStream.stream;

  double speedCurrentMpS() {
    return speedChart.last.$2;
  }

  double distanceM() {
    return distance;
  }

  double durationS() {
    return speedChart.last.$1;
  }

  _updateSpeedChartRaw() {
    if (positionsFiltered.length < 2) {
      return;
    } else if (positionsFiltered.length == 2) {
      speedChartRaw.clear();
    }

    final pos0 = positionsFiltered.elementAt(positionsFiltered.length - 2);
    final pos1 = positionsFiltered.last;
    final dt = pos1.durationS(pos0);
    final s = pos0.speedMS(pos1);

    void addSpeed(double dt, double speed) {
      final t0 = speedChartRaw.lastOrNull?.$1 ?? 0;
      speedChartRaw.add((t0 + dt, speed));
      // print("Adding ${_tSpDebug(dt, speed)}");
    }

    if (pos1.ppState == PPState.running) {
      addSpeed(dt, s);
    }
    if (pos1.ppState == PPState.endPause) {
      addSpeed(0, 0);
    }

    _updateSpeedChart();
  }

  _updateSpeedChart() {
    final segments = speedChartRaw.splitAt((i) => i.$2 == 0);
    speedChart = [];
    for (List<(double, double)> segment in segments) {
      final speeds = segment.map((s) => s.$2).toList();
      speedChart.addAll(
        segment
            .asMap()
            .map((i, s) => MapEntry(i, (s.$1, applyLanczos(speeds, i))))
            .values,
      );
    }
    spChDebug(speedChart);
  }

  List<double> _lanczos(int n2) {
    return List.generate(n2 * 2 + 1, (n) => _sinc(2 * n / (2 * n2) - 1));
  }

  double _sinc(double x) {
    if (x == 0) {
      return 1;
    }
    x *= pi;
    return sin(x) / x;
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

    final filter = lanczos.sublist(lanczosStart, lanczosEnd+1);
    final src = values.sublist(valuesStart, valuesEnd+1);

    double sum = filter.fold(0.0, (a, b) => a + b);
    return src.asMap().entries.fold(
      0.0,
      (a, b) => a + b.value * filter[b.key] / sum,
    );
  }

  List<double> filterValues(List<double> values) {
    return List.generate(values.length, (i) => applyLanczos(values, i));
  }

  String get _posFilterDebug =>
      "${positionsFiltered.windowMap((a, b) => a.speedMS(b).toStringAsFixed(2))}";

  String spChDebug(List<(double, double)> sc){
    return sc.map((a) => _tSpDebug(a.$1, a.$2)).toString();
  }

  static String _tSpDebug(double dt, double speed) {
    return "(${dt.toStringAsFixed(1)}, ${speed.toStringAsFixed(2)})";
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
