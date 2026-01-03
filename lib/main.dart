import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:run_log/configuration.dart';
import 'package:run_log/summary/init_runs.dart';
import 'package:run_log/tabs/running/running.dart';
import 'package:run_log/tabs/settings/settings.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/stats/run_stats.dart';
import 'package:run_log/storage.dart';
import 'package:run_log/tabs/history/history.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class AppFutures {
  final RunStorage runStorage;
  final ConfigurationStorage configurationStorage;

  static Future<AppFutures> start() async {
    return AppFutures(
      runStorage: await RunStorage.initLoad(),
      configurationStorage: await ConfigurationStorage.loadConfig(),
    );
  }

  AppFutures({required this.runStorage, required this.configurationStorage});
}

class _MyAppState extends State<MyApp> {
  late Future<AppFutures> _appFutures;

  @override
  void initState() {
    super.initState();
    _appFutures = AppFutures.start();
  }

  void _handleIncomingIntent(RunStorage runStorage, String altitudeURL) async {
    // For files shared while the app is closed
    List<SharedMediaFile>? initialFiles =
        await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialFiles.isNotEmpty) {
      SharedMediaFile initialFile = initialFiles.first;
      await _processFile(runStorage, initialFile.path, altitudeURL);
    }

    // For files shared while the app is running
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) async {
        if (files.isNotEmpty) {
          await _processFile(runStorage, files.first.path, altitudeURL);
        }
      },
      onError: (err) {
        print("Error in media stream: $err");
      },
    );
  }

  _processFile(
    RunStorage runStorage,
    String filePath,
    String altitudeURL,
  ) async {
    if (filePath.endsWith('.gpx')) {
      await _processGPXFile(runStorage, filePath);
    }
    if (filePath.endsWith('.rlog')) {
      await _processRLogFile(runStorage, filePath);
    }
  }

  _processGPXFile(RunStorage runStorage, String filePath) async {
    File gpxFile = File(filePath);
    String content = await gpxFile.readAsString();
    Run newRun = await runStorage.createRun(DateTime.now());
    List<TrackedData> newData = GpxIO.fromGPX(newRun.id, content);
    for (var td in newData) {
      runStorage.addTrackedData(td);
    }
    newRun.startTime = DateTime.fromMillisecondsSinceEpoch(
      newData.first.timestampMS,
    );
    runStorage.updateRun(newRun);
    RunStats rr = await RunStats.loadRun(runStorage, newRun.id);
    await rr.updateStats();
  }

  _processRLogFile(RunStorage runStorage, String filePath) async {
    File rlogFile = File(filePath);
    String content = await rlogFile.readAsString();
    print("Content is: $content");
    await runStorage.importAll(content);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.run_circle_outlined)),
                Tab(icon: Icon(Icons.list_alt)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
            title: const Text('RunLogger'),
          ),
          body: FutureBuilder<AppFutures>(
            future: _appFutures, // The future we are waiting for
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // While waiting for the future to complete, show a loading indicator
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // If an error occurred during initialization
                return Center(
                  child: Text('Error initializing database: ${snapshot.error}'),
                );
              } else if (snapshot.hasData) {
                // If the future completed successfully and has data (the RunStorage instance)
                final appFutures = snapshot.data!;
                _handleIncomingIntent(
                  appFutures.runStorage,
                  appFutures.configurationStorage.config.altitudeURL,
                );
                InitRuns(
                  appFutures.runStorage,
                  appFutures.configurationStorage,
                ).updateAll();

                return TabBarView(
                  children: [
                    // Pass the initialized RunStorage to the Running widget
                    History(
                      runStorage: appFutures.runStorage,
                      configurationStorage: appFutures.configurationStorage,
                    ),
                    Running(
                      runStorage: appFutures.runStorage,
                      configurationStorage: appFutures.configurationStorage,
                    ),
                    Settings(
                      configurationStorage: appFutures.configurationStorage,
                    ),
                  ],
                );
              } else {
                // Should not happen in typical scenarios
                return const Center(child: Text('Unknown state'));
              }
            },
          ),
        ),
      ),
    );
  }
}
