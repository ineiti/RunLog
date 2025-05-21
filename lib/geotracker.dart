import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

enum GTState {
  permissionRequest,
  permissionRefused,
  waitAccurateGPS,
  positionUpdate,
  paused,
}

/// GeoTracker implements the necessary conversions from GPS coordinates
/// to useful data to be displayed by the app.
class GeoTracker {
  final StreamController<GTState> _controller = StreamController();
  late StreamSubscription<Position> positionStream;
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  double pauseSpeed = 2;
  List<Position> positionsRaw = [];
  List<Position> positionsFiltered = [];
  List<(double, double)> speedChart = [(0, 0)];
  List<double> lanczos = [];

  GeoTracker() {
    lanczos = _lanczos(5);
    _controller.add(GTState.permissionRequest);
    _handlePermission().then((result) {
      if (result) {
        final LocationSettings locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
        positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position? position) {
          // print("New position: $position");
          _handleNewPosition(position!);
        });
        _controller.add(GTState.waitAccurateGPS);
      } else {
        _controller.add(GTState.permissionRefused);
      }
    });
  }

  Stream<GTState> stream() {
    return _controller.stream;
  }

  String fmtSpeedCurrent() {
    final last = positionsFiltered.lastOrNull;
    if (last == null) {
      return "Waiting";
    }
    if (last.speed == 0) {
      return "Paused";
    }
    int length = speedChart.length < 10 ? speedChart.length : 10;
    double sp = speedChart
        .skip(speedChart.length - length)
        .fold(0.0, (a, s) => a + s.$2 / length);
    return "${sp.toStringAsFixed(1)} min/km";
  }

  double distance() {
    if (positionsFiltered.length <= 1) {
      return 0;
    }
    Position prev = positionsFiltered.first;
    double dist = 0;
    for (Position pos in positionsFiltered) {
      if (pos.speed > 0) {
        dist += prev.distance(pos);
      }
      prev = pos;
    }
    return dist;
  }

  double duration() {
    if (positionsFiltered.length <= 1) {
      return 0;
    }
    Position prev = positionsFiltered.first;
    double dur = 0;
    for (Position pos in positionsFiltered) {
      if (pos.speed > 0) {
        dur += pos.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
      }
      prev = pos;
    }
    return dur;
  }

  String fmtSpeedOverall() {
    double dist = distance();
    double dur = duration();
    if (dist > 0 && dur > 0) {
      return _speedStr(dist / duration());
    } else {
      return "Waiting";
    }
  }

  String fmtPauseSpeed() {
    return _speedStr(pauseSpeed);
  }

  void pauseSpeedInc() {
    pauseSpeed += 0.5;
  }

  void pauseSpeedDec() {
    if (pauseSpeed >= 1) {
      pauseSpeed -= 0.5;
    }
  }

  void reset() {
    positionsRaw = [];
    positionsFiltered = [];
    pauseSpeed = 2;
    speedChart = [(0, 0)];
  }

  void share() async {
    final params = ShareParams(
      text: 'Great picture',
      files: [XFile.fromData(Uint8List(0), mimeType: "application/gpx+xml")],
    );

    final result = await SharePlus.instance.share(params);

    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the picture!');
    }
  }

  Widget liveStatsOld() {
    return Text("Hello");
  }

  Widget liveStats() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 350,
      height: 200,
      child: Chart(
        data: speedChart,
        variables: {
          'timestamp': Variable(accessor: ((double, double) l) => l.$1 as num),
          'speed': Variable(accessor: ((double, double) l) => l.$2 as num),
        },
        marks: [
          LineMark(
            shape: ShapeEncode(value: BasicLineShape(dash: [5, 2])),
            selected: {
              'touchMove': {1},
            },
          ),
        ],
        axes: [Defaults.horizontalAxis, Defaults.verticalAxis],
        selections: {
          'touchMove': PointSelection(
            on: {
              GestureType.scaleUpdate,
              GestureType.tapDown,
              GestureType.longPressMoveUpdate,
            },
            dim: Dim.x,
          ),
        },
      ),
    );
  }

  void _handleNewPosition(Position newPosition) {
    if (positionsFiltered.isEmpty) {
      if (newPosition.accuracy > 10) {
        _controller.add(GTState.waitAccurateGPS);
        return;
      }
    }

    final prev = positionsRaw.lastOrNull;
    positionsRaw.add(newPosition);
    if (prev != null && prev.speedCalc(newPosition) < pauseSpeed) {
      print(
        "PosAccuracy ${newPosition.accuracy} - Speed ${prev.speedCalc(newPosition)}",
      );
      _controller.add(GTState.paused);
      if (positionsFiltered.lastOrNull?.speed != 0) {
        print("Adding ${_pausePosition(newPosition)} to posFiltered");
        positionsFiltered.add(_pausePosition(newPosition));
      }
      return;
    }
    positionsFiltered.add(newPosition);
    Position first = positionsFiltered.first;
    print(
      positionsFiltered.skip(1).map((p) {
        double s = first.speedCalc(p);
        first = p;
        return s;
      }),
    );

    _updateSpeedChart();
    _controller.add(GTState.paused);
  }

  _updateSpeedChart() {
    if (positionsFiltered.length < 2) {
      return;
    }
    speedChart.clear();
    Position prev = positionsFiltered.first;
    double timePos = 0;
    for (Position pos in positionsFiltered.skip(1)) {
      if (prev.speed > 0) {
        timePos +=
            pos.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
        speedChart.add((timePos, _speedDouble(prev.speedCalc(pos))));
      }
      prev = pos;
    }
  }

  Position _pausePosition(Position p) {
    return Position(
      longitude: p.longitude,
      latitude: p.latitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      altitude: p.altitude,
      altitudeAccuracy: p.altitudeAccuracy,
      heading: p.heading,
      headingAccuracy: p.headingAccuracy,
      speed: 0,
      speedAccuracy: p.speedAccuracy,
    );
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return false;
    }

    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return false;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return true;
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

  double _speedDouble(double mps) {
    return 1000 / 60 / mps;
  }

  String _speedStr(double mps) {
    return "${_speedDouble(mps).toStringAsFixed(1)} min/km";
  }

  // Applies the lanczos filter to 'values' and keeps the peak at 'pos'.
  // If the lanczos filter doesn't fit, it will be cut and thus not return
  // a nice sampling window.
  double _applyLanczos(List<double> values, int pos) {
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

    final filter = lanczos.sublist(lanczosStart, lanczosEnd);
    final src = values.sublist(valuesStart, valuesEnd);

    double sum = filter.fold(0.0, (a, b) => a + b);
    return src.asMap().entries.fold(
      0.0,
      (a, b) => a + b.value * filter[b.key] / sum,
    );
  }

  List<double> _filterValues(List<double> values) {
    return List.generate(values.length, (i) => _applyLanczos(values, i));
  }
}

extension on Position {
  double distance(Position pos) {
    return Geolocator.distanceBetween(
      this.latitude,
      this.longitude,
      pos.latitude,
      pos.longitude,
    );
  }

  double speedCalc(Position pos) {
    final dist = this.distance(pos);
    if (dist == 0) {
      return -1;
    }
    return dist /
        (this.timestamp.difference(pos.timestamp).inMilliseconds.abs() / 1000);
  }
}
