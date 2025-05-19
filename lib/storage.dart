import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Run {
  late int id;
  int start_time;
  int duration;
  int total_distance;
  int avg_speed;
  int calories_burned;
  String weather;
  int avg_heart_rate;
  int avg_steps_per_min;

  Run({
    required this.id,
    required this.start_time,
    required this.duration,
    required this.total_distance,
    required this.avg_speed,
    required this.calories_burned,
    required this.weather,
    required this.avg_heart_rate,
    required this.avg_steps_per_min,
  });

  factory Run.fromDb(Map<String, dynamic> dbMap) {
    return Run(
      id: dbMap['id'] as int,
      start_time: dbMap['start_time'] as int,
      duration: dbMap['duration'] as int,
      total_distance: dbMap['total_distance'] as int,
      avg_speed: dbMap['avg_speed'] as int,
      calories_burned: dbMap['calories_burned'] as int,
      weather: dbMap['weather'] as String,
      avg_heart_rate: dbMap['avg_heart_rate'] as int,
      avg_steps_per_min: dbMap['avg_steps_per_min'] as int,
    );
  }

  factory Run.start(int start_time) {
    return Run(
      id: 0,
      start_time: start_time,
      duration: 0,
      total_distance: 0,
      avg_speed: 0,
      calories_burned: 0,
      weather: "",
      avg_heart_rate: 0,
      avg_steps_per_min: 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      "start_time": start_time,
      "duration": duration,
      "total_distance": total_distance,
      "avg_speed": avg_speed,
      "calories_burned": calories_burned,
      "weather": weather,
      "avg_heart_rate": avg_heart_rate,
      "avg_steps_per_min": avg_steps_per_min,
    };
  }
}

class TrackedData {
  final int run_id;
  int timestamp;
  double latitude;
  double longitude;
  double gps_accuracy;
  int? heart_rate;
  int? steps_per_min;

  TrackedData({
    required this.run_id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.gps_accuracy,
    this.heart_rate,
    this.steps_per_min,
  });

  factory TrackedData.fromDb(Map<String, dynamic> dbMap) {
    return TrackedData(
      run_id: dbMap['run_id'] as int,
      timestamp: dbMap['timestamp'] as int,
      latitude: dbMap['latitude'] as double,
      longitude: dbMap['longitude'] as double,
      gps_accuracy: dbMap['gps_accuracy'] as double,
      heart_rate: dbMap['heart_rate'] as int?,
      steps_per_min: dbMap['steps_per_min'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "run_id": run_id,
      "timestamp": timestamp,
      "latitude": latitude,
      "longitude": longitude,
      "gps_accuracy": gps_accuracy,
      "heart_rate": heart_rate,
      "steps_per_min": steps_per_min,
    };
  }
}

class RunStorage {
  final Database db;
  List<Run> runs = [];
  Map<int, List<TrackedData>> trackedData = {};

  RunStorage._(this.db);

  // Factory constructor to handle async initialization
  static Future<RunStorage> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final database = await openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'running_log.db'),
      onCreate: (db, version) {
        // Run the CREATE TABLE statement on the database.
        db.execute('''
        CREATE TABLE runs(id INTEGER PRIMARY KEY AUTOINCREMENT,
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
    final rs = RunStorage._(database);
    rs.load();

    return rs;
  }

  void load() async {
    final runMaps = await db.query('runs');
    runs = runMaps.map((map) => Run.fromDb(map)).toList();

    final trackedDataMaps = await db.query('TrackedData');
    final allTrackedData =
        trackedDataMaps.map((map) => TrackedData.fromDb(map)).toList();

    // Group TrackedData by run_id
    trackedData = {};
    for (var data in allTrackedData) {
      if (!trackedData.containsKey(data.run_id)) {
        trackedData[data.run_id] = [];
      }
      trackedData[data.run_id]!.add(data);
    }
  }

  Future<Run> createRun(int startTime) async {
    final run = await addRun(Run.start(startTime));
    runs.add(run);
    trackedData[run.id] = [];
    return run;
  }

  Future<TrackedData> addTrackedData({
    int timestamp = 0,
    int run_id = -1,
    required double latitude,
    required double longitude,
    required double gps_accuracy,
    int? heart_rate,
    int? steps_per_min,
  }) async {
    if (timestamp == 0) {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }
    if (run_id == -1){
      run_id = runs.last.id;
    }
    final data = TrackedData(
      run_id: run_id,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      gps_accuracy: gps_accuracy,
      heart_rate: heart_rate,
      steps_per_min: steps_per_min,
    );
    await db.insert(
      'TrackedData',
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    trackedData[runs.last.id]!.add(data);
    return data;
  }

  Future<Run> addRun(Run run) async {
    run.id = await db.insert(
      'runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return run;
  }
}
