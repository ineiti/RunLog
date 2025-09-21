import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:run_log/feedback/feedback.dart';
import 'package:run_log/stats/conversions.dart';

import '../../storage.dart';
import '../../configuration.dart';
import '../../stats/run_stats.dart';
import '../basic.dart';
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
  late StreamController<RSState> runStateStream;
  StreamSubscription<Position>? geoListen;
  late ToneFeedback feedback;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    runStateStream = StreamController.broadcast();
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
          body: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: _runWidget(snapshot.data),
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
            Flexible(
              flex: 1,
              child: feedback.configWidget(widget.configurationStorage, () {
                setState(() {});
              }),
            ),
            blueButton("Start Running", () => _startRunning()),
          ],
        );
      case RunState.running:
        return _streamBuilder(runStateStream.stream, _widgetRunning);
    }
  }

  _startRunning() {
    feedback.startRunning(
      widget.configurationStorage.config.maxFeedbackSilence,
    );
    RunStats.newRun(widget.runStorage).then((rStats) {
      runStats = rStats;
      rStats.run.feedback = FeedbackContainer.fromPace(feedback.tones.entry);
      widget.runStorage.updateRun(rStats.run);
      runStats!.figures.addSpeed(5);
      runStats!.figures.addSpeed(20);
      if (rStats.run.feedback!.target.targetSpeeds.isNotEmpty) {
        runStats!.figures.addTargetPace(1);
      }
      runStats!.figures.addSlope(20);

      geoListen = geoTracker.streamPosition.listen((pos) async {
        runStats!.addPosition(pos);
        await feedback.updateRunning(
          runStats!.durationSec(),
          runStats!.distanceM(),
        );
        await widget.runStorage.addTrackedData(runStats!.rawPositions.last);
        runStateStream.add(runStats!.state);
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
    final buttons = [
      blueButton("Stop", () {
        setState(() {
          _stop(context);
        });
      }),
    ];
    if (runStats!.run.feedback!.target.targetSpeeds.isNotEmpty) {
      buttons.add(
        blueButton("Reset", () {
          setState(() {
            _reset(context);
          });
        }),
      );
    }
    return <Widget>[
      const Text('Current statistics:'),
      _stats('Curr. Speed: ${pause ? 'Pause' : _fmtSpeedCurrent()}'),
      _stats('Overall speed: ${_fmtSpeedOverall()}'),

      _stats('Duration: ${runStats!.durationSec().toInt()} s'),
      _stats('Distance: ${runStats!.distanceM().toInt()} m'),
      Flex(
        mainAxisAlignment: MainAxisAlignment.center,
        direction: Axis.horizontal,
        spacing: 10,
        children: <Widget>[
          ...buttons,
          feedback.runningWidget(runStats!.durationSec(), () {
            setState(() {});
          }),
        ],
      ),
      runStats!.figures.runStats(),
    ];
  }

  String _fmtSpeedCurrent() {
    final speed = _speedMinKm(runStats!.runningData.last.mps);
    if (speed < 0) {
      return "Waiting";
    } else if (speed == 0) {
      return "Paused";
    }
    return "${shortHMS(speed * 60)}/km";
  }

  String _fmtSpeedOverall() {
    double dist = runStats!.distanceM();
    double dur = runStats!.durationSec();
    if (dist > 0 && dur > 0) {
      return "${shortHMS(_speedMinKm(dist / dur) * 60)}/km";
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

  Widget _stats(String s) {
    return Text(s, style: Theme.of(context).textTheme.headlineMedium);
  }

  _cancel() {
    runStats!.reset();
    geoListen?.cancel();
    widgetController.add(RunState.waitUser);
  }

  _reset(BuildContext context) {
    feedback.tones.sound.reset();
    showDialog<String>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('Sound reset'),
            content: const Text(
              'Sound feedback has been reset - hope it works now!',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
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
