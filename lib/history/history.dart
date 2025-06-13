import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../stats/run_data.dart';
import '../storage.dart';
import '../widgets/basic.dart';
import 'course.dart';

class History extends StatefulWidget {
  const History({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  StreamSubscription<void>? streamSub;

  @override
  void initState() {
    super.initState();
    streamSub = widget.runStorage.updateRuns.stream.listen((void _) {
      setState(() {});
    });
  }

  @override
  dispose() async {
    super.dispose();
    await streamSub?.cancel();
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
              blueButton(
                "Delete",
                () => setState(() {
                  _dbDelete();
                }),
              ),
              blueButton(
                "PreFill",
                () => setState(() {
                  _createTwoTracks();
                }),
              ),
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
                        (context) =>
                            DetailPage(run: run, storage: widget.runStorage),
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

  _createTwoTracks() async {
    await _dbPrefill(
      Duration(hours: 1),
      200,
      [3, .1, .2, .1, .3, .1, .2, .3, .2],
      [0, 1, 5, 2, 1, 2, 5, 2, 5, 3, 5],
    );
    await _dbPrefill(
      Duration(hours: 5),
      100,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
    );
  }

  _dbPrefill(
    Duration before,
    int points,
    List<double> speeds,
    List<double> altitudes,
  ) async {
    var run = await widget.runStorage.createRun(
      DateTime.now().subtract(before),
    );
    final track = _createTracker(
      run.id,
      run.startTime,
      points,
      speeds,
      altitudes,
    );
    for (var td in track) {
      await widget.runStorage.addTrackedData(td);
    }
    run.duration = track.last.timestamp - track.first.timestamp;
    run.totalDistance = track.last.latitude * 6e6 / 180 * pi;
    await widget.runStorage.updateRun(run);
  }

  List<TrackedData> _createTracker(
    int id,
    DateTime start,
    int points,
    List<double> speed,
    List<double> altitude,
  ) {
    final speeds = _cosSeries(points, speed);
    final distances = _integrateList(speeds);
    final altitudes = _cosSeries(points, altitude);
    return List.generate(
      points,
      (i) => TrackedData(
        runId: id,
        timestamp: start.millisecondsSinceEpoch + i * 1000,
        latitude: distances[i] / 6e6 / pi * 180,
        longitude: 0,
        altitude: altitudes[i],
        gpsAccuracy: 5,
      ),
    );
  }

  List<double> _integrateList(List<double> list) {
    List<double> result = [];
    double sum = 0;
    for (var num in list) {
      sum += num;
      result.add(sum);
    }
    return result;
  }

  List<double> _cosSeries(int points, List<double> arg) {
    return List.generate(
      points,
      (i) => arg.asMap().entries.fold(
        0,
        (prev, s) => prev + s.value * cos(s.key * i / points * 2 * pi),
      ),
    );
  }

  _dbDelete() async {
    await widget.runStorage.resetDB();
  }
}
