import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:run_log/stats/track_map.dart';

import '../../configuration.dart';
import '../../stats/conversions.dart';
import '../../stats/run_stats.dart';
import '../../storage.dart';
import '../../stats/run_data.dart';
import '../basic.dart';
import '../dialogs.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.storage,
    required this.configurationStorage,
    required this.run,
  });

  final RunStorage storage;
  final ConfigurationStorage configurationStorage;
  final Run run;

  @override
  State<StatefulWidget> createState() => _DetailPageState();
}

enum _DetailSteps { load, calc, show }

class _DetailPageState extends State<DetailPage> {
  late Stream<_DetailSteps> steps;
  late StreamController<_DetailSteps> source;
  int filterDivisions = 20;
  RunStats? rr;

  @override
  void initState() {
    super.initState();
    source = StreamController<_DetailSteps>();
    steps = source.stream;
    source.add(_DetailSteps.load);
    Timer(Duration(milliseconds: 20), _startCalc);
  }

  Future<void> _startCalc() async {
    final runStats = await RunStats.loadRun(widget.storage, widget.run.id);
    source.add(_DetailSteps.calc);
    // Because flutter will pass the whole class to the Isolate if we
    // pass a field of the class.
    final fd = filterDivisions;
    rr = await Isolate.run(() {
      _updateFigures(runStats, fd);
      return runStats;
    });

    source.add(_DetailSteps.show);
  }

  List<LatLng> get trace => rr!.rawPositions.toLatLng();

  static void _updateFigures(RunStats runStats, int filterDivisions) {
    var fl = runStats.runningData.length ~/ filterDivisions;
    runStats.figureClean();
    runStats.figureAddSpeed(fl);
    if (runStats.run.feedback != null &&
        runStats.run.feedback!.target.targetSpeeds.isNotEmpty) {
      runStats.figureAddTargetPace(1);
    }
    // runStats.figureAddAltitude(fl);
    // runStats.figureAddAltitudeCorrected(fl);
    runStats.figureAddSlope(fl);
    runStats.figureAddFigure();
    runStats.figureAddSlopeStats(fl);
    runStats.figuresUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('dd MMMM yyyy - HH:mm').format(widget.run.startTime),
        ),
      ),
      body: StreamBuilder(
        stream: steps,
        builder: (context, snapshot) {
          switch (snapshot.data) {
            case null:
              return Center(child: Text("Nothing to see here"));
            case _DetailSteps.load:
              return Center(child: Text("Loading"));
            case _DetailSteps.calc:
              return Center(child: Text("Calculating"));
            case _DetailSteps.show:
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: _showCourse(),
              );
          }
        },
      ),
    );
  }

  Widget _showCourse() {
    if (rr == null) {
      return Text("Loading data");
    }
    final children = [
      blueButton("Export", () => _trackExport(context)),
      blueButton("Delete", () => _trackDelete(context)),
      blueButton("Height", () => _trackHeight(context)),
    ];
    if (widget.configurationStorage.config.debug) {
      children.add(blueButton("Clear", () => _trackClear(context)));
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          "${distanceStr(widget.run.totalDistanceM)} in ${timeHMS(widget.run.durationMS / 1000)}: "
          "${minSecFix(widget.run.avgPace(), 1)} min/km",
        ),
        ExpansionTile(
          title: Text("Settings"),
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
                _filterSlider(),
              ],
            ),
          ],
        ),
        rr!.figures.runStats(),
        const SizedBox(height: 12),
        Expanded(child: OpenStreetMapWidget(points: trace)),
      ],
    );
  }

  Widget _filterSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text("Details")]),
        Row(
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // spacing: 10,
          children: [
            Text("$filterDivisions"),
            Flexible(
              flex: 1,
              child: Slider(
                value: pow(200 * filterDivisions, 1 / 2).toDouble(),
                onChanged: (fd) async {
                  setState(() {
                    filterDivisions = (pow(fd, 2) / 200).ceil();
                  });
                  _updateFigures(rr!, filterDivisions);
                },
                min: 1,
                max: 200,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _trackDelete(BuildContext context) async {
    await showDialog<String>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('Delete Run'),
            content: const Text('Do you really want to delete this run?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, 'Cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await widget.storage.removeRun(widget.run.id);
                  // storage.updateRuns.add([]);
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _trackExport(BuildContext context) async {
    final name =
        "run-${DateFormat('yyyy-MM-dd_HH-mm').format(widget.run.startTime)}.gpx";
    final content = rr!.rawPositions.toGPX();
    await showFileActionDialog(context, 'application/gpx+xml', name, content);
  }

  Future<void> _trackHeight(BuildContext context) async {
    StreamController<(int, int)> currentUpdate = StreamController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min, // Important for proper sizing
            children: [
              CircularProgressIndicator(), // The progress bar
              SizedBox(height: 16),
              StreamBuilder(
                stream: currentUpdate.stream,
                builder: (context, snapshot) {
                  return Text(
                    'Fetching Heights ${snapshot.data?.$1} / ${snapshot.data?.$2}',
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    await widget.storage.updateHeightData(
      rr!.run.id,
      widget.configurationStorage.config.altitudeURL,
      (c, t) {
        if (t > 0) {
          setState(() {
            currentUpdate.add((c, t));
          });
        } else {
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _trackClear(BuildContext context) async {
    await widget.storage.clearHeightData(rr!.run.id);
    await _startCalc();
  }
}
