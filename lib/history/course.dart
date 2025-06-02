import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/stats/run_raw.dart';
import 'package:run_log/storage.dart';

import '../stats/run_data.dart';

class DetailPage extends StatelessWidget {
  final Run run;
  final RunStorage storage;
  final RunRaw rr;

  static DetailPage fromRun(Run run, RunStorage storage) {
    final rr = RunRaw.loadRun(storage, run.id);
    rr.addFilter(10);
    rr.addFilter(3);

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
              "${run.avgSpeed().toStringAsFixed(1)}m/s",
            ),
            const SizedBox(height: 10),
            rr.runStats(),
          ],
        ),
      ),
    );
  }
}
