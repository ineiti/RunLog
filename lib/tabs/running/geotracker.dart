import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum GTState { permissionRequest, permissionRefused, permissionGranted }

/// GeoTracker implements the necessary conversions from GPS coordinates
/// to useful data to be displayed by the app.
class GeoTracker {
  final StreamController<GTState> gtStream = StreamController.broadcast();
  final StreamController<Position> gpsPos = StreamController.broadcast();
  final bool simul;
  static const intervalSeconds = 1;
  GTState? state;
  StreamSubscription<Position>? _posSub;
  Timer? _simulTimer;

  GeoTracker({this.simul = false}) {
    gtStream.stream.listen((s) => state = s);
    state = GTState.permissionRequest;
    gtStream.add(GTState.permissionRequest);
    if (simul) {
      Timer(const Duration(seconds: 1), () {
        gtStream.add(GTState.permissionGranted);
      });
    } else {
      unawaited(_gtStreamPermissions());
    }
  }

  Future<void> _gtStreamPermissions() async {
    final bool result = await _handlePermission();

    if (result) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Awaited so the Android 13+ notification permission is resolved
        // before the GPS foreground service starts: the service posts its
        // tracking notification immediately on start, and a still-pending
        // permission means that first notification is silently dropped
        // and never reappears.
        await Permission.notification.request();
      }
      gtStream.add(GTState.permissionGranted);
    } else {
      gtStream.add(GTState.permissionRefused);
    }
  }

  /// Starts the underlying GPS stream. Safe to call multiple times: does
  /// nothing if tracking is already active.
  void startTracking() {
    if (_posSub != null || _simulTimer != null) {
      return;
    }

    if (simul) {
      var latitude = 0.0;
      var now = DateTime.now();
      final interval = Duration(seconds: intervalSeconds);
      _simulTimer = Timer.periodic(interval, (timer) {
        now = now.add(interval);
        double targetSpeed = 5 + sin(latitude / 0.00011 / 3 + pi / 2);
        latitude += 0.00011 * 1.3 * intervalSeconds / targetSpeed;
        gpsPos.add(
          Position(
            longitude: 0,
            latitude: latitude,
            timestamp: now,
            accuracy: 1,
            altitude: 100,
            altitudeAccuracy: 10,
            heading: 0,
            headingAccuracy: 10,
            speed: 10,
            speedAccuracy: 5,
          ),
        );
      });
    } else {
      late LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: intervalSeconds),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText:
            "RunLog continues receiving location updates even when not in foreground",
            notificationTitle: "RunLogging your speed",
            enableWakeLock: true,
          ),
          useMSLAltitude: true,
        );
      } else {
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
      }

      _posSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((pos) {
        gpsPos.add(pos);
      });
    }
  }

  /// Stops the underlying GPS stream. Safe to call multiple times.
  void stopTracking() {
    _simulTimer?.cancel();
    _simulTimer = null;
    unawaited(_posSub?.cancel());
    _posSub = null;
  }

  Stream<GTState> get streamState => gtStream.stream;

  Stream<Position> get streamPosition {
    if (state != GTState.permissionGranted) {
      throw "Permission for position is not granted!";
    }

    return gpsPos.stream;
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    final GeolocatorPlatform geolocatorPlatform = GeolocatorPlatform.instance;

    // Test if location services are enabled.
    serviceEnabled = await geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return false;
    }

    permission = await geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await geolocatorPlatform.requestPermission();
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
}
