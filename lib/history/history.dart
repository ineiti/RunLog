import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/configuration.dart';
import 'package:run_log/stats/conversions.dart';

import '../stats/run_data.dart';
import '../storage.dart';
import '../widgets/basic.dart';
import '../widgets/dialogs.dart';
import 'course.dart';

class History extends StatefulWidget {
  const History({
    super.key,
    required this.runStorage,
    required this.configurationStorage,
  });

  final RunStorage runStorage; // Add RunStorage property
  final ConfigurationStorage configurationStorage; // Configuration

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
        // mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  _debugRuns(),
                  blueButton(
                    "Export All",
                    () => setState(() {
                      _exportAll(context);
                    }),
                  ),
                ],
              ),
            ],
          ),
          runs.isNotEmpty ? _courseList() : Text("No runs yet"),
        ],
      ),
    );
  }

  Widget _debugRuns() {
    if (!widget.configurationStorage.config.debug) {
      return Text("");
    }
    return Row(
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
                        (context) => DetailPage(
                          run: run,
                          configurationStorage: widget.configurationStorage,
                          storage: widget.runStorage,
                        ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
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
                            "${distanceStr(run.totalDistance)} in ${timeHMS(run.duration / 1000)}: "
                            "${minSec(run.avgPace())} min/km",
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
    await DebugStorage.dbPrefill(
      widget.runStorage,
      Duration(hours: 1),
      200,
      [3, .1, .2, .1, .3, .1, .2, .3, .2],
      [0, 1, 5, 2, 1, 2, 5, 2, 5, 3, 5],
    );
    await DebugStorage.dbPrefill(
      widget.runStorage,
      Duration(hours: 5),
      100,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
    );
  }

  _dbDelete() async {
    await widget.runStorage.cleanDB();
  }

  _exportAll(BuildContext context) async {
    final name =
        "runLog-${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.rlog";
    final content = await widget.runStorage.exportAll();
    if (context.mounted) {
      showFileActionDialog(context, 'application/octet-stream', name, content);
    }
  }
}
