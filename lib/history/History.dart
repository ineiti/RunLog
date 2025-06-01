import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../stats/run_data.dart';
import '../storage.dart';
import 'Course.dart';

class History extends StatefulWidget {
  const History({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  late List<Run> runs = List.empty();

  @override
  void initState() {
    super.initState();
    runs = widget.runStorage.runs;
  }

  @override
  Widget build(BuildContext context) {
    print("Items are: ${runs.length}");
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("History"),
      ),
      // body: Column(
      //   children: <Widget>[
      //     Row(
      //       mainAxisAlignment: MainAxisAlignment.center,
      //       children: [
      //         _blueButton("Delete", () => _dbDelete()),
      //         _blueButton("PreFill", () => _dbPrefill()),
      //       ],
      //     ),
      body: runs.isNotEmpty ? _courseList() : Text("No runs yet"),
      // ],
      // ),
    );
  }

  Widget _courseList() {
    return ListView.builder(
      itemCount: runs.length,
      itemBuilder: (context, index) {
        final run = runs[index];
        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetailPage(run: run)),
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
                          "${run.totalDistance.toInt()}m in ${run.duration}s: "
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
    await widget.runStorage.createRun(
      DateTime.now().subtract(Duration(hours: 1)),
    );
    for (double lat = 0; lat < 0.001; lat += 0.0001) {
      await widget.runStorage.addData(
        latitude: lat,
        longitude: 0,
        altitude: 0,
        gpsAccuracy: 0,
      );
    }

    await widget.runStorage.createRun(
      DateTime.now().subtract(Duration(hours: 0)),
    );
    for (double lat = 0; lat < 0.0005; lat += 0.0001) {
      await widget.runStorage.addData(
        latitude: lat,
        longitude: 1,
        altitude: 0,
        gpsAccuracy: 0,
      );
    }

    runs = widget.runStorage.runs;
  }

  _dbDelete() async {
    await widget.runStorage.resetDB();

    runs = widget.runStorage.runs;
  }
}
