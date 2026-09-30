import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:run_log/tabs/running/geotracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForPermission(GeoTracker gt) async {
    await gt.streamState.firstWhere((s) => s == GTState.permissionGranted);
  }

  test(
    'does not emit positions until startTracking() is called',
    () async {
      final gt = GeoTracker(simul: true);
      await waitForPermission(gt);

      final positions = <Position>[];
      final sub = gt.streamPosition.listen(positions.add);

      await Future.delayed(
        Duration(seconds: GeoTracker.intervalSeconds * 3),
      );
      expect(positions, isEmpty);

      await sub.cancel();
    },
  );

  test(
    'emits positions after startTracking() and stops after stopTracking()',
    () async {
      final gt = GeoTracker(simul: true);
      await waitForPermission(gt);

      final positions = <Position>[];
      final sub = gt.streamPosition.listen(positions.add);

      gt.startTracking();
      await Future.delayed(
        Duration(seconds: GeoTracker.intervalSeconds * 3 + 1),
      );
      expect(positions, isNotEmpty);

      gt.stopTracking();
      positions.clear();
      await Future.delayed(
        Duration(seconds: GeoTracker.intervalSeconds * 3),
      );
      expect(positions, isEmpty);

      await sub.cancel();
    },
  );
}
