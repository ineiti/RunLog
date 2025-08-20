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

class _DetailPageState extends State<DetailPage> {
  RunStats? rr;

  @override
  void initState() {
    super.initState();
    RunStats.loadRun(
      widget.storage,
      widget.run.id,
      widget.configurationStorage.config.altitudeURL,
    ).then((runStats) {
      setState(() {
        rr = runStats;
        var fl = rr!.runningData.length ~/ 20;
        // rr!.figureAddSlope(40);
        rr!.figureAddSpeed(fl);
        rr!.figureAddSlope(fl);
        // rr.figureAddSpeed(2);
        // rr.figureAddSpeed(100);
        // rr!.figureAddAltitude(10);
        // rr!.figureAddAltitudeCorrected(10);
        rr!.figureAddFigure();
        // rr!.figureAddAltitude(10);
        // rr!.figureAddAltitudeCorrected(10);
        rr!.figureAddSlopeStats(fl);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('dd MMMM yyyy - HH:mm').format(widget.run.startTime),
        ),
      ),
      body: Padding(
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
