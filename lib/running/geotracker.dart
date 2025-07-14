import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum GTState { permissionRequest, permissionRefused, permissionGranted }

/// GeoTracker implements the necessary conversions from GPS coordinates
/// to useful data to be displayed by the app.
class GeoTracker {
  final StreamController<GTState> gtStream = StreamController.broadcast();
  final bool simul;
  GTState? state;

  GeoTracker({this.simul = false}) {
    gtStream.stream.listen((s) => state = s);
    if (simul) {
      state = GTState.permissionRequest;
      Timer.periodic(const Duration(seconds: 1), (timer) {
        gtStream.add(GTState.permissionGranted);
        timer.cancel();
      });
    }
    gtStream.add(GTState.permissionRequest);
    _handlePermission().then((result) {
      if (result) {
        gtStream.add(GTState.permissionGranted);
      } else {
        gtStream.add(GTState.permissionRefused);
      }
    });
  }

  Stream<GTState> get streamState => gtStream.stream;

  Stream<Position> get streamPosition {
    if (state != GTState.permissionGranted) {
      throw "Permission for position is not granted!";
    }

    if (simul) {
      final streamPos = StreamController<Position>.broadcast();
      var latitude = 0.0;
      var now = DateTime.now();
      Timer.periodic(const Duration(seconds: 2), (timer) {
        now = now.add(Duration(seconds: 2));
        latitude += 0.00011;
        streamPos.add(
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
      return streamPos.stream;
    }

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 5),
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

    return Geolocator.getPositionStream(locationSettings: locationSettings);
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
