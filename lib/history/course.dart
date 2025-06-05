import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/stats/conversions.dart';
import 'package:run_log/stats/run_raw.dart';
import 'package:run_log/storage.dart';

import '../stats/run_data.dart';

class DetailPage extends StatelessWidget {
  final Run run;
  final RunStorage storage;
  final RunRaw rr;

  static DetailPage fromRun(Run run, RunStorage storage) {
    final rr = RunRaw.loadRun(storage, run.id);
    rr.figureAddSpeed(10);
    // rr.figureAddSpeed(100);
    rr.figureAddSlope(2);
    rr.figureAddAltitude(10);

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
            ...rr.figures.runStats(),
          ],
        ),
      ),
    );
  }
}
