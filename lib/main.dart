import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:run_log/running/running.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/stats/run_stats.dart';
import 'package:run_log/storage.dart';

import 'history/history.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<RunStorage> _runStorageFuture;

  @override
  void initState() {
    super.initState();
    _runStorageFuture = RunStorage.init(); // Initialize RunStorage
  }

  void _handleIncomingIntent(RunStorage runStorage) async {
    // For files shared while the app is closed
    print("handling incoming intent");
    List<SharedMediaFile>? initialFiles =
        await ReceiveSharingIntent.instance.getInitialMedia();
    print("getInitialMedia returned");
    if (initialFiles.isNotEmpty) {
      print("got initialFiles");
      SharedMediaFile initialFile = initialFiles.first;
      if (initialFile.path.endsWith('.gpx')) {
        print("getInitialMedia: ${initialFile.mimeType}");
        _processGPXFile(runStorage, initialFile.path);
      }
    }

    // For files shared while the app is running
    var some = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        print("got media stream");
        if (files.isNotEmpty && files.first.path.endsWith('.gpx')) {
          print("GetMediaStream: ${files.first.mimeType}");
          _processGPXFile(runStorage, files.first.path);
          _processGPXFile(runStorage, files.first.path);
        }
      },
      onError: (err) {
        print("Error in media stream: $err");
      },
    );
    print("set up listening - $some");
  }

  void _processGPXFile(RunStorage runStorage, String filePath) async {
    File gpxFile = File(filePath);
    String content = await gpxFile.readAsString();
    Run newRun = await runStorage.createRun(DateTime.now());
    List<TrackedData> newData = GpxIO.fromGPX(newRun.id, content);
    for (var td in newData) {
      runStorage.addTrackedData(td);
    }
    newRun.startTime = DateTime.fromMillisecondsSinceEpoch(
      newData.first.timestamp,
    );
    runStorage.updateRun(newRun);
    RunStats rr = await RunStats.loadRun(runStorage, newRun.id);
    await rr.updateStats();
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
          body: FutureBuilder<RunStorage>(
            future: _runStorageFuture, // The future we are waiting for
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
                final runStorage = snapshot.data!;
                _handleIncomingIntent(runStorage);

                return TabBarView(
                  children: [
                    // Pass the initialized RunStorage to the Running widget
                    History(runStorage: runStorage),
                    Running(runStorage: runStorage),
                    const Icon(Icons.directions_bike),
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
