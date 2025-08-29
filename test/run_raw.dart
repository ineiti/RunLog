import 'package:geolocator/geolocator.dart';
import 'package:test/test.dart';

import 'package:run_log/stats/run_data.dart';
import 'package:run_log/stats/run_stats.dart';

void main() {
  test('Waiting for accuracy', () {
    PositionMock pm = PositionMock();
    RunStats rr = RunStats(
      rawPositions: [],
      run: Run(id: 1, startTime: DateTime.now()),
    );
    expect(rr.state, RSState.waitAccurateGPS);
    rr.addPosition(pm.pos.withAccuracy(rr.minAccuracy * 2));
    expect(rr.state, RSState.waitAccurateGPS);
    rr.addPosition(pm.pos.withAccuracy(rr.minAccuracy));
    expect(rr.state, RSState.waitAccurateGPS);
    rr.addPosition(pm.pos.withAccuracy(rr.minAccuracy / 2));
    expect(rr.state, RSState.waitRunning);
  });

  test('Start running', () {
    PositionMock pm = PositionMock();
    RunStats rr = RunStats(
      rawPositions: [],
      run: Run(id: 1, startTime: DateTime.now()),
    );
    rr.addPosition(pm.pos);
    expect(rr.state, RSState.waitRunning);
    rr.addPosition(pm.stepSlow());
    expect(rr.state, RSState.waitRunning);
    rr.addPosition(pm.stepSlow());
    expect(rr.state, RSState.waitRunning);
    rr.addPosition(pm.stepFast());
    expect(rr.state, RSState.running);
    rr.addPosition(pm.stepFast());
    expect(rr.state, RSState.running);
  });

  test('Resampling TrackData', () {
    final r = Run.now(1);
    final pm = PositionMock(run: r);
    final rs = Resampler(pm.td);
    expect(rs.resample(pm.td.withTimestamp(pm.td.timestamp + 1)), [pm.td]);
    expect(rs.resample(pm.td.withTimestamp(pm.td.timestamp + 2)), []);
    expect(
      rs.resample(pm.td.withTimestamp(pm.td.timestamp + rs.sampleInterval)),
      [pm.td],
    );
  });
}

class PositionMock {
  final pause = 0.00005;
  final slow = 0.0001;
  final fast = 0.00015;
  final dt = 5.0;
  Run? run;

  PositionMock({this.run});

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

  TrackedData tdPause() {
    // print("** Adding Pause");
    return run!.tdFromPosition(incLongitude(pause, dt));
  }

  TrackedData tdSlow() {
    // print("** Adding Slow");
    return run!.tdFromPosition(incLongitude(slow, dt));
  }

  TrackedData tdFast() {
    // print("** Adding Fast");
    return run!.tdFromPosition(incLongitude(fast, dt));
  }

  TrackedData get td => run!.tdFromPosition(pos);
}

extension PositionModifiers on Position {
  /// Returns a new Position with updated accuracy
  Position withAccuracy(double newAccuracy) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    altitude: altitude,
    accuracy: newAccuracy,
    altitudeAccuracy: altitudeAccuracy,
    headingAccuracy: headingAccuracy,
    heading: heading,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    isMocked: isMocked,
  );

  /// Returns a new Position with updated latitude
  Position withLatitude(double newLatitude) => Position(
    latitude: newLatitude,
    longitude: longitude,
    timestamp: timestamp,
    altitude: altitude,
    accuracy: accuracy,
    altitudeAccuracy: altitudeAccuracy,
    headingAccuracy: headingAccuracy,
    heading: heading,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    isMocked: isMocked,
  );

  /// Returns a new Position with updated longitude
  Position withLongitude(double newLongitude) => Position(
    latitude: latitude,
    longitude: newLongitude,
    timestamp: timestamp,
    altitude: altitude,
    accuracy: accuracy,
    altitudeAccuracy: altitudeAccuracy,
    headingAccuracy: headingAccuracy,
    heading: heading,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    isMocked: isMocked,
  );

  Position withTimestamp(DateTime timestamp) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    altitude: altitude,
    accuracy: accuracy,
    altitudeAccuracy: altitudeAccuracy,
    headingAccuracy: headingAccuracy,
    heading: heading,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    isMocked: isMocked,
  );
}
