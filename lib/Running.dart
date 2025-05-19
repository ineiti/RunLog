import 'dart:async';

import 'package:flutter/material.dart';
import 'package:run_log/storage.dart';
import 'package:geolocator/geolocator.dart';

class Running extends StatefulWidget {
  const Running({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<Running> createState() => _RunningState();
}

class _RunningState extends State<Running> {
  late StreamSubscription<Position> positionStream;
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  List<Position> lastPositions = [];
  Position? paused;
  double meanSpeed = 0;
  double duration = 0;
  double distance = 0;
  double pauseSpeed = 1;

  @override
  void initState() {
    super.initState();

    _handlePermission().then((result) {
      setState(() {
        // Update state
      });
    });

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position? position) {
      print("New position: $position");
      _handleNewPosition(position!);
    });
  }

  void _handleNewPosition(Position newPosition) {
    setState(() {
      print("Speed: ${newPosition.speed} / ${newPosition.speedAccuracy}");
      print("Position accuracy: ${newPosition.accuracy}");
      final previous = paused ?? lastPositions.lastOrNull;
      if (previous != null) {
        final segment = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );
        final double split =
            newPosition.timestamp
                .difference(previous.timestamp)
                .inMilliseconds /
            1000;

        print("Segnent ($segment) / Split ($split) = ${segment / split}");
        if (segment / split < pauseSpeed) {
          paused = newPosition;
          return;
        }
        paused = null;
        distance += segment;
        duration += split;
      }

      lastPositions.add(newPosition);
      if (lastPositions.length > 10) {
        lastPositions.removeAt(0);
      }

      meanSpeed =
          lastPositions.map((p) => p.speed).reduce((a, b) => a + b) /
          lastPositions.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("RunLog"),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Current statistics:'),
            Text(
              'Curr. Speed: ${_speedCurr()}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Overall speed: ${_speedOverall()}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Duration: ${duration.toInt()} s',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Distance: ${distance.toInt()} m',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'PauseSpeed: ${((1000 / 60) / pauseSpeed).toStringAsFixed(1)} min/km',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.lightBlue,
              ),
              onPressed: () {
                setState(() {
                  pauseSpeed = ((2 * pauseSpeed).round() + 1) / 2;
                });
              },
              child: Text('Increase pauseSpeed'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.lightBlue,
              ),
              onPressed: () {
                if (pauseSpeed >= 1) {
                  setState(() {
                    pauseSpeed = ((2 * pauseSpeed).round() - 1) / 2;
                  });
                }
              },
              child: Text('Decrease pauseSpeed'),
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementSpeedPause,
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  String _speedCurr() {
    if (paused != null) {
      return "Paused";
    }
    if (meanSpeed > 0) {
      return "${((1000 / 60) / meanSpeed).toStringAsFixed(1)} min/km";
    } else {
      return "Waiting";
    }
  }

  String _speedOverall() {
    if (distance > 0) {
      return "${((1000 / 60) / (distance / duration)).toStringAsFixed(1)} min/km";
    } else {
      return "Waiting";
    }
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
}
