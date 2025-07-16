import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';
import 'package:run_log/storage.dart';

import '../configuration.dart';
import '../stats/run_stats.dart';
import '../widgets/basic.dart';
import 'geotracker.dart';
import 'tone_feedback.dart';

class Running extends StatefulWidget {
  const Running({
    super.key,
    required this.runStorage,
    required this.configurationStorage,
  });

  final RunStorage runStorage; // Add RunStorage property
  final ConfigurationStorage configurationStorage; // Configuration

  @override
  State<Running> createState() => _RunningState();
}

enum RunState { waitGPS, waitUser, running }

class _RunningState extends State<Running> with AutomaticKeepAliveClientMixin {
  late GeoTracker geoTracker;
  RunStats? runStats;
  StreamController<RunState> widgetController = StreamController.broadcast();
  late Stream<RSState> runStream;
  late ToneFeedback feedback;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    geoTracker = GeoTracker(
      simul: widget.configurationStorage.config.simulateGPS,
    );
    ToneFeedback.init().then((f) {
      feedback = f;
    });
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
        widgetController.add(RunState.waitGPS);
        return Text("Initializing");
      case RunState.waitGPS:
        return _streamBuilder(geoTracker.streamState, _widgetWaitGPS);
      case RunState.waitUser:
        return Column(
          children: [
            ...feedback.configWidget(() {
              setState(() {});
            }),
            blueButton("Start Running", () => _startRunning()),
          ],
        );
      case RunState.running:
        return _streamBuilder(runStream, _widgetRunning);
    }
  }

  _startRunning() {
    feedback.startRunning(widget.configurationStorage.config.maxFeedbackIndex);
    RunStats.newRun(widget.runStorage).then((rr) {
      runStats = rr;
      runStats!.figures.addSpeed(5);
      runStats!.figures.addSpeed(20);
      runStats!.figures.addSlope(20);
      runStream = runStats!.continuous(geoTracker.streamPosition);
      runStream.listen((state) async {
        await feedback.updateRunning(
          runStats!.duration(),
          runStats!.distance(),
        );
      });
      widgetController.add(RunState.running);
    });
  }

  Widget _streamBuilder<T>(
    Stream<T> stream,
    Function(BuildContext context, T?) showWidget,
  ) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        return Flex(
          direction: Axis.vertical,
          children: showWidget(context, snapshot.data),
        );
      },
    );
  }

  List<Widget> _widgetWaitGPS(BuildContext context, GTState? s) {
    // print("_widgetWaitGPS($s) - ${geoTracker.state}");
    // print("${s ?? geoTracker.state}");
    switch (s ?? geoTracker.state) {
      case null:
        return [_stats("Starting up")];
      case GTState.permissionRequest:
        return [_stats("Waiting for permission")];
      case GTState.permissionRefused:
        return [_stats("Permission refused - restart")];
      case GTState.permissionGranted:
        widgetController.add(RunState.waitUser);
        return [_stats("Permission Granted")];
    }
  }

  List<Widget> _widgetRunning(BuildContext context, RSState? s) {
    // print("RRState is $s");
    switch (s ?? runStats?.state) {
      case null:
        return [_stats("Waiting for GPS")];
      case RSState.waitAccurateGPS:
        var last = runStats!.rawPositions.lastOrNull;
        return [
          _stats("Waiting for accurate GPS:"),
          _stats(
            last != null
                ? "Current accuracy: ${last.gpsAccuracy.toInt()}m"
                : "Waiting for first GPS reading",
          ),
          _stats(
            last != null
                ? "Required accuracy: ${runStats!.minAccuracy.toInt()}m"
                : "",
          ),
        ];
      case RSState.waitRunning:
        return [_stats("Ready to run! GO!!!")];
      case RSState.running:
        return _showRunning(context, false);
      case RSState.paused:
        return _showRunning(context, true);
    }
  }

  List<Widget> _showRunning(BuildContext context, bool pause) {
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
          blueButton("Stop", () {
            setState(() {
              _stop(context);
            });
          }),
          feedback.runningWidget(runStats!.duration(), () {
            setState(() {});
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

  _cancel() {
    // print("Cancelling");
    runStats!.reset();
    widgetController.add(RunState.waitUser);
  }

  _stop(BuildContext context) {
    if (runStats!.runningData.last.mps < runStats!.minSpeedStart ||
        runStats!.runPaused) {
      _cancel();
    } else {
      showDialog<String>(
        context: context,
        builder:
            (BuildContext context) => AlertDialog(
              title: const Text('Stop Run'),
              content: const Text('Do you really want to stop this run?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    _cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('End Run'),
                ),
              ],
            ),
      );
    }
  }
}
