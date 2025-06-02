import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:run_log/storage.dart';
import 'package:share_plus/share_plus.dart';

import '../stats/run_raw.dart';
import 'geotracker.dart';

class Running extends StatefulWidget {
  const Running({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<Running> createState() => _RunningState();
}

enum RState { waitGPS, running }

class _RunningState extends State<Running> with AutomaticKeepAliveClientMixin {
  late GeoTracker geoTracker;
  late RunRaw runRaw;
  late Stream<RRState> runStream;
  RState runState = RState.waitGPS;
  StreamController<RState> runStateStream = StreamController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    geoTracker = GeoTracker();
    RunRaw.newRun(widget.runStorage).then((rr) {
      rr.addFilter(10);
      rr.addFilter(3);
      runRaw = rr;
      runStateStream.stream.listen((RState? rs) {
        if (rs != null) {
          setState(() {
            runState = rs;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    switch (runState) {
      case RState.waitGPS:
        return _streamBuilder(geoTracker.stream, _widgetWaitGPS);
      case RState.running:
        return _streamBuilder(runStream, _widgetRunning);
    }
  }

  Widget _streamBuilder<T>(Stream<T> stream, Function(T?) showWidget) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
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
                Flex(
                  direction: Axis.vertical,
                  children: showWidget(snapshot.data),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _widgetWaitGPS(GTState? s) {
    // print("_widgetWaitGPS($s)");
    switch (s) {
      case null:
        return [_stats("Starting up")];
      case GTState.permissionRequest:
        return [_stats("Waiting for permission")];
      case GTState.permissionRefused:
        return [_stats("Permission refused - restart")];
      case GTState.permissionGranted:
        runStream = runRaw.continuous(geoTracker.positionStream);
        runStateStream.add(RState.running);
        return [_stats("Permission Granted")];
    }
  }

  List<Widget> _widgetRunning(RRState? s) {
    // print("RRState is $s");
    switch (s) {
      case null:
        return [_stats("Waiting for GPS")];
      case RRState.waitAccurateGPS:
        return [
          _stats("Waiting for accurate GPS:"),
          _stats(
            "Current accuracy: ${runRaw.rawPositions.last.gpsAccuracy.toInt()}m",
          ),
          _stats("Required accuracy: ${runRaw.minAccuracy.toInt()}m"),
        ];
      case RRState.waitRunning:
        return [_stats("Ready to run! GO!!!")];
      case RRState.running:
        return _showRunning(false);
      case RRState.paused:
        return _showRunning(true);
    }
  }

  List<Widget> _showRunning(bool pause) {
    return <Widget>[
      const Text('Current statistics:'),
      _stats('Curr. Speed: ${pause ? 'Pause' : _fmtSpeedCurrent()}'),
      _stats('Overall speed: ${_fmtSpeedOverall()}'),

      _stats('Duration: ${runRaw.duration().toInt()} s'),
      _stats('Distance: ${runRaw.distance().toInt()} m'),
      Flex(
        mainAxisAlignment: MainAxisAlignment.center,
        direction: Axis.horizontal,
        spacing: 10,
        children: <Widget>[
          _blueButton("--", () {
            _speedRunDec();
          }),
          Text("MinSpeedrun: ${_speedStrMinKm(runRaw.minSpeedRun)}"),
          _blueButton("++", () {
            _speedRunInc();
          }),
        ],
      ),
      Flex(
        mainAxisAlignment: MainAxisAlignment.center,
        direction: Axis.horizontal,
        spacing: 10,
        children: <Widget>[
          _blueButton("Reset", () {
            runRaw.reset();
            runStateStream.add(RState.running);
          }),
          _blueButton("Share", () {
            _share();
          }),
        ],
      ),
      runRaw.runStats(),
    ];
  }

  String _fmtSpeedCurrent() {
    final speed = _speedMinKm(runRaw.rawSpeed.last.mps);
    if (speed < 0) {
      return "Waiting";
    } else if (speed == 0) {
      return "Paused";
    }
    return "${speed.toStringAsFixed(1)} min/km";
  }

  String _fmtSpeedOverall() {
    double dist = runRaw.distance();
    double dur = runRaw.duration();
    if (dist > 0 && dur > 0) {
      return _speedStrMinKm(dist / dur);
    } else {
      return "Waiting";
    }
  }

  double _speedMinKm(double mps) {
    if (mps <= 0) {
      return mps;
    }
    return 1000 / 60 / mps;
  }

  String _speedStrMinKm(double mps) {
    return "${_speedMinKm(mps).toStringAsFixed(1)} min/km";
  }

  void _speedRunInc() {
    runRaw.minSpeedRun += 0.25;
  }

  void _speedRunDec() {
    if (runRaw.minSpeedRun >= 0.5) {
      runRaw.minSpeedRun -= 0.25;
    }
  }

  void _share() async {
    final params = ShareParams(
      text: 'run_log.gpx',
      files: [XFile.fromData(Uint8List(0), mimeType: "application/gpx+xml")],
    );

    final result = await SharePlus.instance.share(params);

    if (result.status == ShareResultStatus.success) {
      print('File shared');
    }
  }

  Widget _stats(String s) {
    return Text(s, style: Theme.of(context).textTheme.headlineMedium);
  }

  Widget _blueButton(String s, VoidCallback click) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.lightBlue,
      ),
      onPressed: () {
        setState(() {
          click();
        });
      },
      child: Text(s),
    );
  }
}
