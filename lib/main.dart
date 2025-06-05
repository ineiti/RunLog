import 'package:flutter/material.dart';
import 'package:run_log/running/running.dart';
import 'package:run_log/storage.dart';

import 'history/history.dart';

void main() {
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
