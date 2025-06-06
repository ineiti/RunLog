import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/stats/conversions.dart';
import 'package:run_log/stats/run_raw.dart';
import 'package:run_log/storage.dart';
import 'package:share_plus/share_plus.dart';

import '../stats/run_data.dart';

class DetailPage extends StatelessWidget {
  final Run run;
  final RunStorage storage;
  final RunRaw rr;

  static DetailPage fromRun(Run run, RunStorage storage) {
    final rr = RunRaw.loadRun(storage, run.id);
    for (int i = 1; i < 300; i++){
      print("$i - ${rr.rawPositions[rr.rawPositions.length-i].gpsAccuracy}");
    }
    rr.figureAddSpeed(20);
    // rr.figureAddSpeed(2);
    // rr.figureAddSpeed(100);
    rr.figureAddSlope(20);
    // rr.figureAddAltitude(100);

    return DetailPage(run: run, storage: storage, rr: rr);
  }

  const DetailPage({
    super.key,
    required this.run,
    required this.storage,
    required this.rr,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('dd MMMM yyyy - HH:mm').format(run.startTime)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "${run.totalDistance.toInt()}m in ${run.duration ~/ 1000}s: "
              "${paceMinKm(run.avgSpeed()).toStringAsFixed(1)} min/km",
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _blueButton("Export", () => _trackExport()),
                _blueButton("Delete", () => _trackDelete(context)),
              ],
            ),
            const SizedBox(height: 10),
            ...rr.figures.runStats(),
          ],
        ),
      ),
    );
  }

  Widget _blueButton(String s, VoidCallback click) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.lightBlue,
      ),
      onPressed: () {
        click();
      },
      child: Text(s),
    );
  }

  _trackDelete(BuildContext context) async {
    return showDialog<String>(
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
                  await storage.removeRun(run.id);
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

  _trackExport() async {
    final content = rr.rawPositions.toGPX();
    final name =
        "run-${DateFormat('yyyy-MM-dd_HH:mm').format(run.startTime)}.gpx";
    final params = ShareParams(
      files: [
        XFile.fromData(utf8.encode(content), mimeType: 'application/gpx+xml'),
      ],
      fileNameOverrides: [name],
    );

    await SharePlus.instance.share(params);
  }
}
