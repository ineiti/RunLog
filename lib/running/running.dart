import 'dart:async';

import 'package:flutter/material.dart';
import 'package:run_log/storage.dart';

import '../stats/run_stats.dart';
import '../widgets/basic.dart';
import 'geotracker.dart';

class Running extends StatefulWidget {
  const Running({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<Running> createState() => _RunningState();
}

enum RunState { waitUser, waitGPS, running }

class _RunningState extends State<Running> with AutomaticKeepAliveClientMixin {
  late GeoTracker geoTracker;
  RunStats? runStats;
  StreamController<RunState> widgetController = StreamController.broadcast();
  late Stream<RSState> runStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    geoTracker = GeoTracker();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder(
      stream: widgetController.stream,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text("RunLog"),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[_runWidget(snapshot.data)],
            ),
          ),
        );
      },
    );
  }

  Widget _runWidget(RunState? rs) {
    switch (rs) {
      case null:
        widgetController.add(RunState.waitUser);
        return Text("Initializing");
      case RunState.waitUser:
        return blueButton("Start Running", () {
          widgetController.add(RunState.waitGPS);
        });
      case RunState.waitGPS:
        return _streamBuilder(geoTracker.stream, _widgetWaitGPS);
      case RunState.running:
        return _streamBuilder(runStream, _widgetRunning);
    }
  }

  Widget _streamBuilder<T>(Stream<T> stream, Function(T?) showWidget) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        return Flex(
          direction: Axis.vertical,
          children: showWidget(snapshot.data),
        );
      },
    );
  }

  List<Widget> _widgetWaitGPS(GTState? s) {
    print("_widgetWaitGPS($s) - ${geoTracker.state}");
    print("${s ?? geoTracker.state}");
    switch (s ?? geoTracker.state) {
      case null:
        return [_stats("Starting up")];
      case GTState.permissionRequest:
        return [_stats("Waiting for permission")];
      case GTState.permissionRefused:
        return [_stats("Permission refused - restart")];
      case GTState.permissionGranted:
        RunStats.newRun(widget.runStorage).then((rr) {
          runStats = rr;
          runStats!.figures.addSpeed(5);
          runStats!.figures.addSpeed(20);
          runStats!.figures.addSlope(20);
          runStream = runStats!.continuous(geoTracker.positionStream);
          widgetController.add(RunState.running);
        });
        return [_stats("Permission Granted")];
    }
  }

  List<Widget> _widgetRunning(RSState? s) {
    // print("RRState is $s");
    switch (s) {
      case null:
        return [_stats("Waiting for GPS")];
      case RSState.waitAccurateGPS:
        return [
          _stats("Waiting for accurate GPS:"),
          _stats(
            "Current accuracy: ${runStats!.rawPositions.last.gpsAccuracy.toInt()}m",
          ),
          _stats("Required accuracy: ${runStats!.minAccuracy.toInt()}m"),
        ];
      case RSState.waitRunning:
        return [_stats("Ready to run! GO!!!")];
      case RSState.running:
        return _showRunning(false);
      case RSState.paused:
        return _showRunning(true);
    }
  }

  List<Widget> _showRunning(bool pause) {
    return <Widget>[
      const Text('Current statistics:'),
      _stats('Curr. Speed: ${pause ? 'Pause' : _fmtSpeedCurrent()}'),
      _stats('Overall speed: ${_fmtSpeedOverall()}'),

      _stats('Duration: ${runStats!.duration().toInt()} s'),
      _stats('Distance: ${runStats!.distance().toInt()} m'),
      Flex(
        mainAxisAlignment: MainAxisAlignment.center,
        direction: Axis.horizontal,
        spacing: 10,
        children: <Widget>[
          blueButton("Reset", () {
            setState(() {
              runStats!.reset();
              widgetController.add(RunState.running);
            });
          }),
          blueButton("Stop", () {
            setState(() {
              _stop();
            });
          }),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: runStats!.figures.runStats(),
      ),
    ];
  }

  String _fmtSpeedCurrent() {
    final speed = _speedMinKm(runStats!.runningData.last.mps);
    if (speed < 0) {
      return "Waiting";
    } else if (speed == 0) {
      return "Paused";
    }
    return "${speed.toStringAsFixed(1)} min/km";
  }

  String _fmtSpeedOverall() {
    double dist = runStats!.distance();
    double dur = runStats!.duration();
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

  Widget _stats(String s) {
    return Text(s, style: Theme.of(context).textTheme.headlineMedium);
  }

  _stop() {
    if (runStats!.runningData.last.mps < runStats!.minSpeedStart ||
        runStats!.runPaused) {
      runStats?.cancel();
      widgetController.add(RunState.waitUser);
    }
  }
}
