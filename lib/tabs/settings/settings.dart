import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:run_log/app_log.dart';
import 'package:run_log/backup.dart';
import 'package:run_log/storage.dart';
import 'package:run_log/tabs/basic.dart';
import 'package:run_log/tabs/dialogs.dart';

import '../../configuration.dart';

class Settings extends StatefulWidget {
  const Settings({
    super.key,
    required this.runStorage,
    required this.configurationStorage,
  });

  final RunStorage runStorage;
  final ConfigurationStorage configurationStorage; // Configuration

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final TextEditingController _altitudeURL = TextEditingController();
  late Future<List<SnapshotInfo>> _snapshotsFuture;

  @override
  void initState() {
    super.initState();
    _altitudeURL.text = widget.configurationStorage.config.altitudeURL;
    _snapshotsFuture = AppBackup.listSnapshots();
  }

  void _reloadSnapshots() {
    setState(() {
      _snapshotsFuture = AppBackup.listSnapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedPaceMin =
        (widget.configurationStorage.config.minFeedbackPace * 12).round() / 12;
    final feedPaceMax =
        (widget.configurationStorage.config.maxFeedbackPace * 12).round() / 12;
    // final divisionsMin = ((feedPaceMax - 1) * 12).round();
    // final divisionsMax = ((10 - feedPaceMin) * 12).round();
    // print("$feedPaceMin..$feedPaceMax - $divisionsMin / $divisionsMax");
    // print("Items are: ${runs.length} - ${widget.runStorage.runs}");
    // print(widget.runStorage);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Settings"),
      ),
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          spacing: 10,
          children: <Widget>[
            CheckboxListTile(
              title: Text("Debug mode"),
              value: widget.configurationStorage.config.debug,
              onChanged: (bool? value) async {
                if (value != null) {
                  await widget.configurationStorage.updateConfig(
                    widget.configurationStorage.config.setDebug(value),
                  );
                  setState(() {});
                }
              },
            ),
            CheckboxListTile(
              title: Text("Simulate GPS"),
              value: widget.configurationStorage.config.simulateGPS,
              onChanged: (bool? value) async {
                if (value != null) {
                  await widget.configurationStorage.updateConfig(
                    widget.configurationStorage.config.setSimulateGPS(value),
                  );
                  setState(() {});
                }
              },
            ),
            TextField(
              controller: _altitudeURL,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Altitude URL',
              ),
              onChanged: (String s) async {
                await widget.configurationStorage.updateConfig(
                  widget.configurationStorage.config.setAltitudeURL(s),
                );
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Max. feedback silence"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${widget.configurationStorage.config.maxFeedbackSilence} x",
                    ),
                    Flexible(
                      child: Slider(
                        value:
                            widget
                                .configurationStorage
                                .config
                                .maxFeedbackSilence
                                .toDouble(),
                        onChanged: (double value) async {
                          await widget.configurationStorage.updateConfig(
                            widget.configurationStorage.config
                                .setMaxFeedbackIndex(value.toInt()),
                          );
                          setState(() {});
                        },
                        min: 1,
                        divisions: 10,
                        max: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            paceSlider(
              (newValue) async {
                await widget.configurationStorage.updateConfig(
                  widget.configurationStorage.config.setMinFeedbackPace(
                    newValue,
                  ),
                );
                setState(() {});
              },
              feedPaceMin,
              "MinPace",
              1,
              feedPaceMax,
            ),
            paceSlider(
              (newValue) async {
                await widget.configurationStorage.updateConfig(
                  widget.configurationStorage.config.setMaxFeedbackPace(
                    newValue,
                  ),
                );
                setState(() {});
              },
              feedPaceMax,
              "MaxPace",
              feedPaceMin,
              10,
            ),
            CheckboxListTile(
              title: Text("Announce Target Change"),
              value: widget.configurationStorage.config.announceTargetChange,
              onChanged: (bool? value) async {
                if (value != null) {
                  await widget.configurationStorage.updateConfig(
                    widget.configurationStorage.config.setAnnounceTargetChange(value),
                  );
                  setState(() {});
                }
              },
            ),
            _backupsSection(),
          ],
        ),
      ),
    );
  }

  Widget _backupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Backups", style: Theme.of(context).textTheme.titleMedium),
        FutureBuilder<List<SnapshotInfo>>(
          future: _snapshotsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            final snaps = snapshot.data!;
            final latest = snaps.isNotEmpty ? snaps.first : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest == null
                      ? "Latest: none yet"
                      : "Latest: ${DateFormat('yyyy-MM-dd HH:mm').format(latest.timestamp)} (${latest.runCount} runs)",
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (snaps.isNotEmpty)
                      blueButton(
                        "Restore",
                        () => _showRestoreList(context, snaps),
                      ),
                    if (latest != null)
                      blueButton(
                        "Share / Save",
                        () => _shareSnapshot(latest),
                      ),
                    blueButton("View log", () => _showLog(context)),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showRestoreList(
    BuildContext context,
    List<SnapshotInfo> snaps,
  ) async {
    final protected = AppBackup.protectedPath(snaps);
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children:
                snaps.map((snap) {
                  final isProtected = snap.path == protected;
                  return ListTile(
                    title: Text(
                      "${DateFormat('yyyy-MM-dd HH:mm').format(snap.timestamp)} "
                      "(${snap.runCount} runs)"
                      "${isProtected ? " — protected" : ""}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        Navigator.pop(context);
                        await AppBackup.deleteSnapshot(snap);
                        _reloadSnapshots();
                      },
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _confirmRestore(context, snap);
                    },
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _confirmRestore(BuildContext context, SnapshotInfo snap) async {
    await showDialog<void>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('Restore Backup'),
            content: Text(
              "This will replace the current ${widget.runStorage.runs.length} "
              "runs with the ${snap.runCount} runs from "
              "${DateFormat('yyyy-MM-dd HH:mm').format(snap.timestamp)}. "
              "A safety snapshot of the current state will be taken first.",
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await AppBackup.restore(widget.runStorage, snap);
                  _reloadSnapshots();
                },
                child: const Text('Restore'),
              ),
            ],
          ),
    );
  }

  Future<void> _shareSnapshot(SnapshotInfo snap) async {
    final bytes = await File(snap.path).readAsBytes();
    if (mounted) {
      await showFileBytesActionDialog(
        context,
        'application/octet-stream',
        snap.fileName,
        bytes,
      );
    }
  }

  Future<void> _showLog(BuildContext context) async {
    final log = await AppLog.readAll();
    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Log",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        final outerContext = this.context;
                        Navigator.pop(context);
                        await showFileActionDialog(
                          outerContext,
                          'text/plain',
                          'runlog.log',
                          log,
                        );
                      },
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      log.isEmpty ? "(empty)" : log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
