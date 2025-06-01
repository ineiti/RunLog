import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/storage.dart';

import '../stats/run_data.dart';

class DetailPage extends StatelessWidget {
  final Run run;

  const DetailPage({super.key, required this.run});

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
              "${run.totalDistance.toInt()}m in ${run.duration}s: "
              "${run.avgSpeed()}m/s",
            ),
            const SizedBox(height: 10),
            Text(run.avgStepsPerMin.toString()),
          ],
        ),
      ),
    );
  }
}
