import 'package:geolocator/geolocator.dart';
import 'package:run_log/positiontracker.dart';
import 'package:test/test.dart';

void main() {
  test('Applying Lanczos', () {
    var pt = PositionTracker.testPT(PositionMock().pos);
    expect(pt.applyLanczos([10], 0), equals(10));
    expect(
      pt.filterValues([0, 0, 10, 0, 0]).fold(0.0, (a, b) => a + b),
      greaterThan(10),
    );
    print(pt.filterValues([10, 10, 20, 10, 10]));
    print(pt.filterValues([10,10,10,10]));
  });

  test('Starting a measurement', () {
    var pos = PositionMock();
    var pt = PositionTracker.testPT(pos.pos);
    pt.handleNewPosition(pos.stepPause());
    pt.handleNewPosition(pos.stepPause());
    expect(pt.speedChartRaw.length, equals(1));
    expect(pt.speedChart.length, equals(1));
    expect(pt.positionsRaw.length, equals(3));
    expect(pt.positionsFiltered.length, equals(1));

    pt.handleNewPosition(pos.stepSlow());
    expect(pt.speedChartRaw.length, equals(1));
    expect(pt.positionsRaw.length, equals(4));
    expect(pt.positionsFiltered.length, equals(2));
  });

  test('Running - pausing - running', () {
    var pos = PositionMock();
    var pt = PositionTracker.testPT(pos.pos);
    pt.handleNewPosition(pos.stepSlow());
    pt.handleNewPosition(pos.stepFast());
    pt.handleNewPosition(pos.stepSlow());
    expect(pt.speedChartRaw.length, equals(3));
    expect(pt.positionsRaw.length, equals(4));
    expect(pt.positionsFiltered.length, equals(4));
    pt.handleNewPosition(pos.stepPause());
    expect(pt.speedChartRaw.length, equals(3));
    pt.handleNewPosition(pos.stepPause());
    expect(pt.speedChartRaw.length, equals(3));
    pt.handleNewPosition(pos.stepPause());
    expect(pt.speedChartRaw.length, equals(3));
    pt.handleNewPosition(pos.stepSlow());
    expect(pt.speedChartRaw.length, equals(5));
    pt.handleNewPosition(pos.stepFast());
    expect(pt.speedChartRaw.length, equals(6));
  });
}

class PositionMock {
  final pause = 0.00005;
  final slow = 0.0001;
  final fast = 0.00015;
  final dt = 5.0;

  Position pos = Position(
    longitude: 0,
    latitude: 0,
    timestamp: DateTime.timestamp(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  Position incLongitude(double l, double dt) {
    pos = Position(
      longitude: pos.longitude + l,
      latitude: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        pos.timestamp.millisecondsSinceEpoch + (dt * 1000).toInt(),
      ),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    return pos;
  }

  Position stepPause() {
    // print("** Adding Pause");
    return incLongitude(pause, dt);
  }

  Position stepSlow() {
    // print("** Adding Slow");
    return incLongitude(slow, dt);
  }

  Position stepFast() {
    // print("** Adding Fast");
    return incLongitude(fast, dt);
  }
}
