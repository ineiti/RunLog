import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:run_log/app_log.dart';
import 'package:run_log/backup.dart';
import 'package:run_log/configuration.dart';
import 'package:run_log/summary/init_runs.dart';
import 'package:run_log/tabs/running/running.dart';
import 'package:run_log/tabs/settings/settings.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/stats/run_stats.dart';
import 'package:run_log/storage.dart';
import 'package:run_log/tabs/history/history.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    unawaited(AppLog.write("FlutterError: ${details.exceptionAsString()}"));
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(AppLog.write("Uncaught error: $error\n$stack"));
    return true;
  };
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
    final runStorage = await RunStorage.initLoad();
    // Must run after initLoad() (migrations applied) and must never be able
    // to fail app launch -- item 1b removing the auto-wipe is what makes
    // snapshotting here safe: a load error now throws instead of wiping the
    // DB before we get a chance to snapshot it.
    try {
      await AppBackup.createSnapshot(runStorage.db, force: false);
    } catch (e) {
      await AppLog.write("Startup snapshot failed: $e");
    }
    return AppFutures(
      runStorage: runStorage,
      configurationStorage: await ConfigurationStorage.loadConfig(),
    );
  }

  AppFutures({required this.runStorage, required this.configurationStorage});
}

final GlobalKey<ScaffoldState> tabKey = GlobalKey<ScaffoldState>();

class _MyAppState extends State<MyApp> {
  late Future<AppFutures> _appFutures;

  @override
  void initState() {
    super.initState();
    _appFutures = AppFutures.start();
  }

  Future<void> _asyncCalls(AppFutures appFutures) async {
    await _handleIncomingIntent(
      appFutures.runStorage,
      appFutures.configurationStorage.config.altitudeURL,
    );
    await InitRuns(
      appFutures.runStorage,
      appFutures.configurationStorage,
    ).updateAll();
  }

  Future<void> _handleIncomingIntent(RunStorage runStorage, String altitudeURL) async {
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
      onError: (Object err) {
        print("Error in media stream: $err");
      },
    );
  }

  Future<void> _processFile(
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

  Future<void> _processGPXFile(RunStorage runStorage, String filePath) async {
    File gpxFile = File(filePath);
    String content = await gpxFile.readAsString();
    Run newRun = await runStorage.createRun(DateTime.now());
    var (newData, feedback) = GpxIO.fromGPX(newRun.id, content);
    for (TrackedData td in newData) {
      await runStorage.addTrackedData(td);
    }
    newRun.startTime = DateTime.fromMillisecondsSinceEpoch(
      newData.first.timestampMS,
    );
    if (feedback != null){
      newRun.feedback = feedback;
    }
    await runStorage.updateRun(newRun);
    RunStats rr = await RunStats.loadRun(runStorage, newRun.id);
    rr.updateStats();
  }

  Future<void> _processRLogFile(RunStorage runStorage, String filePath) async {
    File rlogFile = File(filePath);
    String content = await rlogFile.readAsString();
    try {
      await AppBackup.createSnapshot(runStorage.db, force: true);
    } catch (e) {
      await AppLog.write("Pre-import snapshot failed: $e");
    }
    await runStorage.importAll(content);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        initialIndex: 1,
        child: Scaffold(
          key: tabKey,
          appBar: AppBar(
            bottom: const TabBar(
              tabs: <Widget>[
                Tab(icon: Icon(Icons.run_circle_outlined)),
                Tab(icon: Icon(Icons.list_alt)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
            title: const Text('RunLogger'),
          ),
          body: FutureBuilder<AppFutures>(
            future: _appFutures, // The future we are waiting for
            builder: (BuildContext context, AsyncSnapshot<AppFutures> snapshot) {
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
                final AppFutures appFutures = snapshot.data!;
                unawaited(_asyncCalls(appFutures));

                return TabBarView(
                  children: <Widget>[
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
                      runStorage: appFutures.runStorage,
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
