import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../stats/run_data.dart';
import '../storage.dart';
import 'course.dart';

class History extends StatefulWidget {
  const History({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  @override
  void initState() {
    super.initState();
  }

  List<Run> get runs =>
      widget.runStorage.runs.values.toList().reversed.toList();

  @override
  Widget build(BuildContext context) {
    // print("Items are: ${runs.length} - ${widget.runStorage.runs}");
    // print(widget.runStorage);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("History"),
      ),
      body: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _blueButton("Delete", () => _dbDelete()),
              _blueButton("PreFill", () => _dbPrefill()),
            ],
          ),
          runs.isNotEmpty ? _courseList() : Text("No runs yet"),
        ],
      ),
    );
  }

  Widget _courseList() {
    return Expanded(
      child: ListView.builder(
        itemCount: runs.length,
        itemBuilder: (context, index) {
          final run = runs[index];
          return Card(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => DetailPage.fromRun(run, widget.runStorage),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Image.network(
                    //   item.imageUrl,
                    //   width: 80,
                    //   height: 80,
                    //   fit: BoxFit.cover,
                    // ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'yyyy - MMMM - dd - HH:mm',
                            ).format(run.startTime),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            "${run.totalDistance.toInt()}m in ${run.duration / 1000}s: "
                            "${run.avgSpeed().toStringAsFixed(1)}m/s",
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
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
        setState(() {
          click();
        });
      },
      child: Text(s),
    );
  }

  _dbPrefill() async {
    var run = await widget.runStorage.createRun(
      DateTime.now().subtract(Duration(hours: 1)),
    );
    for (int i = 0; i < 10; i++) {
      await widget.runStorage.addData(
        runId: run.id,
        latitude: 0.0001 * i,
        longitude: 0,
        altitude: 0,
        gpsAccuracy: 0,
        timestamp: i * 5000,
      );
    }
    run.duration = 10 * 5000;
    run.totalDistance = 100;
    await widget.runStorage.updateRun(run);

    run = await widget.runStorage.createRun(
      DateTime.now().subtract(Duration(hours: 0)),
    );
    for (int i = 0; i < 20; i++) {
      await widget.runStorage.addData(
        runId: run.id,
        latitude: 0.0001 * i,
        longitude: 1,
        altitude: 0,
        gpsAccuracy: 0,
        timestamp: i * 5000,
      );
    }
    run.duration = 20 * 5000;
    run.totalDistance = 200;
    await widget.runStorage.updateRun(run);
  }

  _dbDelete() async {
    await widget.runStorage.resetDB();
  }
}
