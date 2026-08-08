import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_log.dart';
import '../../backup.dart';
import '../../configuration.dart';
import '../../stats/conversions.dart';
import '../../stats/run_data.dart';
import '../../storage.dart';
import '../basic.dart';
import '../dialogs.dart';
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
  Future<void> dispose() async {
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
                  _debugRuns(context),
                  blueButton("Export All", () async {
                    await _exportAll(context);
                    setState(() {});
                  }),
                ],
              ),
            ],
          ),
          runs.isNotEmpty ? _courseList() : Text("No runs yet"),
        ],
      ),
    );
  }

  Widget _debugRuns(BuildContext context) {
    if (!widget.configurationStorage.config.debug) {
      return Text("");
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        blueButton("Delete", () async {
          await _confirmDbDelete(context);
          setState(() {});
        }),
        blueButton("PreFill", () async {
          await _createTwoTracks();
          setState(() {});
        }),
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
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
                    if (run.summary?.mapIcon != null) ...[
                      Image.memory(run.summary!.mapIcon!),
                      const SizedBox(width: 12),
                    ],
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
                            "${distanceStr(run.totalDistanceM)} in ${timeHMS(run.durationMS / 1000)}: "
                            "${minSecFix(run.avgPace(), 1)} min/km",
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

  Future<void> _createTwoTracks() async {
    await DebugStorage.dbPrefill(
      widget.runStorage,
      Duration(hours: 1),
      200,
      [3, .1, .2, .1, .3, .1, .2, .3, .2],
      [0, 1, 5, 2, 1, 2, 5, 2, 5, 3, 5],
      null,
    );
    await DebugStorage.dbPrefill(
      widget.runStorage,
      Duration(hours: 5),
      100,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
      null,
    );
  }

  Future<void> _confirmDbDelete(BuildContext context) async {
    await showDialog<String>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('Delete All Runs'),
            content: const Text(
              'Do you really want to delete all runs? This cannot be undone '
              'from within the app.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, 'Cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await _dbDelete();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _dbDelete() async {
    try {
      await AppBackup.createSnapshot(widget.runStorage.db, force: true);
    } catch (e) {
      await AppLog.write("Pre-delete snapshot failed: $e");
    }
    await widget.runStorage.cleanDB();
  }

  Future<void> _exportAll(BuildContext context) async {
    final name =
        "runLog-${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.rlog";
    final content = await widget.runStorage.exportAll();
    if (context.mounted) {
      await showFileActionDialog(
        context,
        'application/octet-stream',
        name,
        content,
      );
    }
  }
}
