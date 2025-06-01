import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum GTState { permissionRequest, permissionRefused, permissionGranted }

/// GeoTracker implements the necessary conversions from GPS coordinates
/// to useful data to be displayed by the app.
class GeoTracker {
  final StreamController<GTState> gtStream = StreamController();
  late Stream<Position> positionStream;

  GeoTracker() {
    gtStream.add(GTState.permissionRequest);
    _handlePermission().then((result) {
      if (result) {
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
          );
        } else {
          locationSettings = LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          );
        }
        positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        );
        gtStream.add(GTState.permissionGranted);
      } else {
        gtStream.add(GTState.permissionRefused);
      }
    });
  }

  Stream<GTState> get stream => gtStream.stream;

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
