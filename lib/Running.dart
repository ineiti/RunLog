import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:run_log/positiontracker.dart';
import 'package:run_log/storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_core/core.dart';

import 'geotracker.dart';

class Running extends StatefulWidget {
  const Running({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<Running> createState() => _RunningState();
}

enum RState { waitGPS, running }

class _RunningState extends State<Running> {
  late GeoTracker geoTracker;
  late PositionTracker posTracker;
  RState runState = RState.waitGPS;
  StreamController<RState> runStateStream = StreamController();

  @override
  void initState() {
    super.initState();
    geoTracker = GeoTracker();
    runStateStream.stream.listen((RState? rs) {
      if (rs != null) {
        setState(() {
          runState = rs;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    switch (runState) {
      case RState.waitGPS:
        return _streamBuilder(geoTracker.stream, _widgetWaitGPS);
      case RState.running:
        return _streamBuilder(posTracker.stream, _widgetRunning);
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
    print("_widgetWaitGPS($s)");
    switch (s) {
      case null:
        return [_stats("Starting up")];
      case GTState.permissionRequest:
        return [_stats("Waiting for permission")];
      case GTState.permissionRefused:
        return [_stats("Permission refused - restart")];
      case GTState.permissionGranted:
        posTracker = PositionTracker(geoTracker.positionStream);
        runStateStream.add(RState.running);
        return [_stats("Permission Granted")];
    }
  }

  List<Widget> _widgetRunning(PTState? s) {
    switch (s) {
      case null:
        return [_stats("Unknown state")];
      case PTState.waitFirstFix:
        return [_stats("Waiting for GPS")];
      case PTState.waitAccurateGPS:
        return [
          _stats("Waiting for accurate GPS:"),
          _stats(
            "${posTracker.accuracy.toInt()} > ${posTracker.accuracyMin.toInt()}",
          ),
        ];
      case PTState.waitRunning:
        return [_stats("Ready to run! GO!!!")];
      case PTState.positionUpdate:
        return _showRunning(false);
      case PTState.paused:
        return _showRunning(true);
    }
  }

  List<Widget> _showRunning(bool pause) {
    var max = (_speedMinKm(
      posTracker.speedChart.reduce((a, b) => a.mps < b.mps ? a : b).mps,
    ) * 6 + 1).toInt() / 6;
    var min = (_speedMinKm(
      posTracker.speedChart.reduce((a, b) => a.mps > b.mps ? a : b).mps,
    ) * 6 - 1).toInt() / 6;
    var med = (max + min) / 2;
    if (med + 0.5 > max){
      max = med + 0.5;
    }
    if (med - 0.5 < min){
      min = med -0.5;
    }
    return <Widget>[
      const Text('Current statistics:'),
      _stats('Curr. Speed: ${pause ? 'Pause' : _fmtSpeedCurrent()}'),
      _stats('Overall speed: ${_fmtSpeedOverall()}'),

      _stats('Duration: ${posTracker.durationS().toInt()} s'),
      _stats('Distance: ${posTracker.distanceM().toInt()} m'),
      Flex(
        mainAxisAlignment: MainAxisAlignment.center,
        direction: Axis.horizontal,
        spacing: 10,
        children: <Widget>[
          _blueButton("--", () {
            _pauseSpeedDec();
          }),
          Text("PauseSpeed: ${_speedStrMinKm(posTracker.pauseSpeed)}"),
          _blueButton("++", () {
            _pauseSpeedInc();
          }),
        ],
      ),
      Flex(
        mainAxisAlignment: MainAxisAlignment.center,
        direction: Axis.horizontal,
        spacing: 10,
        children: <Widget>[
          _blueButton("Reset", () {
            posTracker.reset();
          }),
          _blueButton("Share", () {
            _share();
          }),
        ],
      ),
      Container(
        margin: const EdgeInsets.only(top: 10),
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelIntersectAction: AxisLabelIntersectAction.multipleRows,
          ),
          primaryYAxis: NumericAxis(
            isInversed: true,
            minimum: min,
            maximum: max,
            axisLabelFormatter:
                (AxisLabelRenderDetails details) {
                  final value = double.parse(details.text);
                  final min = value.toInt();
                  final sec = ((value - min) * 60).round();
                  if (sec == 0) {
                    return ChartAxisLabel("$min'", details.textStyle);
                  } else {
                    return ChartAxisLabel("$min' $sec''", details.textStyle);
                  }
                },
          ),
          legend: Legend(isVisible: true),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<TimeData, String>>[
            LineSeries<TimeData, String>(
              dataSource: posTracker.speedChart,
              xValueMapper: (TimeData entry, _) => _timeHMS(entry.dt),
              yValueMapper: (TimeData entry, _) => _speedMinKm(entry.mps),
              name: 'Speed [min/km]',
              dataLabelSettings: DataLabelSettings(isVisible: false),
            ),
          ],
        ),
      ),
    ];
  }

  String _fmtSpeedCurrent() {
    final speed = _speedMinKm(posTracker.speedCurrentMpS());
    if (speed < 0) {
      return "Waiting";
    } else if (speed == 0) {
      return "Paused";
    }
    return "${speed.toStringAsFixed(1)} min/km";
  }

  String _fmtSpeedOverall() {
    double dist = posTracker.distanceM();
    double dur = posTracker.durationS();
    if (dist > 0 && dur > 0) {
      return _speedStrMinKm(dist / dur);
    } else {
      return "Waiting";
    }
  }

  String _timeHMS(double s) {
    final hours = (s / 60 / 60).toInt();
    final mins = (s / 60 % 60).toInt();
    final sec = (s % 60).toInt();
    if (hours > 0) {
      return "${hours}h ${mins}m ${sec}s";
    } else if (mins > 0) {
      return "${mins}m ${sec}s";
    } else {
      return "${sec}s";
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

  void _pauseSpeedInc() {
    posTracker.pauseSpeed += 0.25;
  }

  void _pauseSpeedDec() {
    if (posTracker.pauseSpeed >= 1) {
      posTracker.pauseSpeed -= 0.25;
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
