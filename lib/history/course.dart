import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/configuration.dart';
import 'package:run_log/stats/conversions.dart';
import 'package:run_log/stats/run_stats.dart';
import 'package:run_log/storage.dart';

import '../stats/run_data.dart';
import '../widgets/basic.dart';
import '../widgets/dialogs.dart';

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
  RunStats? rr;

  @override
  void initState() {
    super.initState();
    source = StreamController<_DetailSteps>();
    steps = source.stream;
    source.add(_DetailSteps.load);
    Timer(Duration(milliseconds: 20), _startCalc);
  }

  void _startCalc() async {
    final runStats = await RunStats.loadRun(
      widget.storage,
      widget.run.id,
      widget.configurationStorage.config.altitudeURL,
    );
    source.add(_DetailSteps.calc);
    rr = await Isolate.run(() {
      var fl = runStats.runningData.length ~/ 20;
      runStats.figureAddSpeed(fl);
      // runStats.figureAddAltitude(fl);
      // runStats.figureAddAltitudeCorrected(fl);
      runStats.figureAddSlope(fl);
      runStats.figureAddFigure();
      runStats.figureAddSlopeStats(fl);
      runStats.figuresUpdate();
      return runStats;
    });

    source.add(_DetailSteps.show);
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      "${distanceStr(widget.run.totalDistance)} in ${timeHMS(widget.run.duration / 1000)}: "
                      "${minSec(widget.run.avgPace())} min/km",
                    ),
                    const SizedBox(height: 10),
                    ..._figures(),
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  List<Widget> _figures() {
    if (rr == null) {
      return [Text("Loading data")];
    }
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          blueButton("Export", () => _trackExport(context)),
          blueButton("Delete", () => _trackDelete(context)),
        ],
      ),
      const SizedBox(height: 10),
      ...rr!.figures.runStats(),
    ];
  }

  _trackDelete(BuildContext context) async {
    showDialog<String>(
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

  _trackExport(BuildContext context) async {
    final name =
        "run-${DateFormat('yyyy-MM-dd_HH-mm').format(widget.run.startTime)}.gpx";
    final content = rr!.rawPositions.toGPX();
    showFileActionDialog(context, 'application/gpx+xml', name, content);
  }
}
