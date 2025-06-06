import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:sqflite/sqflite.dart';

class RunStorage {
  StreamController<void> updateRuns = StreamController.broadcast();
  late Database db;
  Map<int, Run> runs = {};
  Map<int, List<TrackedData>> trackedData = {};

  RunStorage._(this.db);

  // Factory constructor to handle async initialization
  static Future<RunStorage> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final rs = RunStorage._(await _getDB());
    await rs.load();

    return rs;
  }

  Future<void> load() async {
    final runMaps = await db.query('Runs');
    final runList = runMaps.map((map) => Run.fromDb(map)).toList();
    runs = {for (var run in runList) run.id: run};

    final trackedDataMaps = await db.query('TrackedData');
    final allTrackedData =
        trackedDataMaps.map((map) => TrackedData.fromDb(map)).toList();

    // Group TrackedData by run_id
    trackedData = {};
    for (var data in allTrackedData) {
      if (!trackedData.containsKey(data.runId)) {
        trackedData[data.runId] = [];
      }
      trackedData[data.runId]!.add(data);
    }
    updateRuns.add([]);
  }

  Future<Run> createRun(DateTime startTime) async {
    final run = await _addRun(Run.start(startTime));
    runs[run.id] = run;
    trackedData[run.id] = [];
    updateRuns.add([]);
    return run;
  }

  removeRun(int id) async {
    await db.delete('TrackedData', where: 'run_id = ?', whereArgs: [id]);
    await db.delete('Runs', where: 'id = ?', whereArgs: [id]);
    runs.remove(id);
    trackedData.remove(id);
    updateRuns.add([]);
  }

  Future<TrackedData> addData({
    int timestamp = -1,
    required int runId,
    required double latitude,
    required double longitude,
    required double altitude,
    required double gpsAccuracy,
    int? heartRate,
    int? stepsPerMin,
  }) async {
    if (timestamp == -1) {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }
    final data = TrackedData(
      runId: runId,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      gpsAccuracy: gpsAccuracy,
      heartRate: heartRate,
      stepsPerMin: stepsPerMin,
    );
    await addTrackedData(data);
    return data;
  }

  addTrackedData(TrackedData td) async {
    await db.insert(
      'TrackedData',
      td.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    trackedData[td.runId]!.add(td);
  }

  Future<Run> _addRun(Run run) async {
    run.id = await db.insert(
      'Runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return run;
  }

  updateRun(Run run) async {
    // print("Updating ${run.id} out of $runs in $this");
    db.update('Runs', run.toMap(), where: "id = ?", whereArgs: [run.id]);
    runs[run.id] = run;
  }

  resetDB() async {
    db.delete('Runs');
    db.delete('TrackedData');
    db.close();
    await deleteDatabase(await _dbPath());
    db = await _getDB();
    runs = {};
    trackedData = {};
    await load();
  }

  @override
  String toString() {
    return "Storage(${identityHashCode(this)}) - $runs";
  }

  static Future<String> _dbPath() async {
    return join(await getDatabasesPath(), 'running_log.db');
  }

  static Future<Database> _getDB() async {
    return await openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await _dbPath()),
      onCreate: (db, version) {
        // print("Creating db");
        // Run the CREATE TABLE statement on the database.
        db.execute('''
        CREATE TABLE Runs(id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_time INTEGER NOT NULL,
          duration INTEGER NOT NULL,
          total_distance REAL NOT NULL,
          avg_speed REAL,
          calories_burned INTEGER,
          weather TEXT,
          avg_heart_rate INTEGER,
          avg_steps_per_min INTEGER
        );''');
        db.execute('''
        CREATE TABLE TrackedData (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          run_id INTEGER NOT NULL,
          timestamp INTEGER NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          altitude REAL NOT NULL,
          gps_accuracy REAL,
          heart_rate INTEGER,
          steps_per_min INTEGER,
          FOREIGN KEY (run_id) REFERENCES Runs(id)
        );''');
        return db.execute('''        
        CREATE INDEX idx_trackeddata_run_id ON TrackedData (run_id);
        ''');
      },
      version: 1,
    );
  }
}
