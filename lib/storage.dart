import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:sqflite/sqflite.dart';

class RunStorage {
  StreamController<void> updateRuns = StreamController.broadcast();
  late Database db;
  Map<int, Run> runs = {};
  Map<int, List<TrackedData>> _trackedData = {};

  RunStorage._(this.db);

  // Factory constructor to handle async initialization
  static Future<RunStorage> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final rs = RunStorage._(await _getDB());
    await rs.loadRuns();

    return rs;
  }

  Future<void> loadRuns() async {
    final runMaps = await db.query('Runs');
    final runList = runMaps.map((map) => Run.fromDb(map)).toList();
    runs = {for (var run in runList) run.id: run};

    updateRuns.add([]);
  }

  Future<List<TrackedData>> loadTrackedData(
    int runId,
    String altitudeURL,
  ) async {
    // if (_trackedData.containsKey(runId)) {
    //   return _trackedData[runId]!;
    // }

    final trackedDataMaps = await db.query(
      'TrackedData',
      where: "run_id = ?",
      whereArgs: [runId],
    );
    // print("Got ${trackedDataMaps.length} entries - ${trackedDataMaps[0]}");
    final allTrackedData =
        trackedDataMaps.map((map) => TrackedData.fromDb(map)).toList();

    // Update trackedData with real altitude reading, if available
    final List<int> tdUpdate = [];
    for (int i = 0; i < allTrackedData.length; i++) {
      if (allTrackedData[i].altitudeCorrected == null) {
        tdUpdate.add(i);
      }
      if (tdUpdate.length >= 100) {
        print("Updating batch $i / ${allTrackedData.length / 100} entries");
        await _updateTrackedData(allTrackedData, tdUpdate, altitudeURL);
        tdUpdate.clear();
      }
    }
    await _updateTrackedData(allTrackedData, tdUpdate, altitudeURL);

    _trackedData[runId] = [];
    for (var data in allTrackedData) {
      _trackedData[runId]!.add(data);
    }

    return _trackedData[runId]!;
  }

  _updateTrackedData(
    List<TrackedData> allTrackedData,
    List<int> tdUpdate,
    String altitudeURL,
  ) async {
    if (tdUpdate.isEmpty) {
      return;
    }
    try {
      final acs = await _fetchAltitudes(
        tdUpdate
            .map(
              (i) => (allTrackedData[i].latitude, allTrackedData[i].longitude),
            )
            .toList(),
        altitudeURL,
      );
      if (acs.length == tdUpdate.length) {
        for (int i in tdUpdate) {
          allTrackedData[i].altitudeCorrected = acs.removeAt(0);
          await _updateTD(allTrackedData[i]);
        }
      }
    } catch (e) {
      print("Couldn't fetch entries: $e");
    }
  }

  Future<List<double?>> _fetchAltitudes(
    List<(double, double)> pos,
    String altitudeURL,
  ) async {
    final locations =
        "?locations=${pos.map((ll) => "${ll.$1.toStringAsFixed(6)},${ll.$2.toStringAsFixed(6)}").join("|")}";
    // print("Locations are: $locations");
    final url =
        dotenv.env["TOPO_URL"] ??
        (altitudeURL != ""
            ? altitudeURL
            : 'https://api.opendata.org/v1/eudem25m');
    print("Getting altitudes from $url");
    final response = await http.get(
      Uri.parse("$url$locations"),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Parse the JSON response
      final results =
          (jsonDecode(response.body) as Map<String, dynamic>)["results"];
      try {
        final List<double?> elevations = [
          for (final result in results)
            // double.parse(result["elevation"].toString()),
            double.tryParse(result["elevation"].toString()),
        ];
        for (int i = 0; i < elevations.length; i++) {
          if (elevations[i] == null) {
            if (i > 0 && elevations[i - 1] != null) {
              elevations[i] = elevations[i - 1];
            } else if (i < elevations.length - 1 && elevations[i + 1] != null) {
              elevations[i] = elevations[i + 1];
            }
          }
        }
        // print("Elevations are: $elevations");
        return elevations;
      } catch (e) {
        print("Error while converting: $e - $results");
        for (final r in results) {
          if (r["elevation"] == null) {
            print(r);
          }
        }
        return [];
      }
    } else {
      print(response.statusCode);
      throw Exception('Failed to load data');
    }
  }

  Future<Run> createRun(DateTime startTime) async {
    final run = await _addRun(Run.start(startTime));
    runs[run.id] = run;
    _trackedData[run.id] = [];
    updateRuns.add([]);
    return run;
  }

  removeRun(int id) async {
    await db.delete('TrackedData', where: 'run_id = ?', whereArgs: [id]);
    await db.delete('Runs', where: 'id = ?', whereArgs: [id]);
    runs.remove(id);
    _trackedData.remove(id);
    updateRuns.add([]);
  }

  Future<TrackedData> addData({
    int timestamp = -1,
    required int runId,
    required double latitude,
    required double longitude,
    required double altitude,
    required double gpsAccuracy,
    double? altitudeCorrected,
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
      altitudeCorrected: altitudeCorrected,
      gpsAccuracy: gpsAccuracy,
      heartRate: heartRate,
      stepsPerMin: stepsPerMin,
    );
    if (data.altitudeCorrected == null) {
      final ac = await _fetchAltitudes([(data.latitude, data.longitude)], "");
      if (ac.length == 1) {
        data.altitudeCorrected = ac[0];
      }
    }
    await addTrackedData(data);
    return data;
  }

  addTrackedData(TrackedData td) async {
    await db.insert(
      'TrackedData',
      td.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _trackedData[td.runId]!.add(td);
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
    await db.update('Runs', run.toMap(), where: "id = ?", whereArgs: [run.id]);
    runs[run.id] = run;
  }

  _updateTD(TrackedData td) async {
    // print("Updating ${run.id} out of $runs in $this");
    await db.update(
      'TrackedData',
      td.toMap(),
      where: "id = ?",
      whereArgs: [td.id],
    );
  }

  resetDB() async {
    db.delete('Runs');
    db.delete('TrackedData');
    db.close();
    await deleteDatabase(await _dbPath());
    db = await _getDB();
    runs = {};
    _trackedData = {};
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
      onCreate: (db, newVersion) async {
        // print("Creating db");
        // Run the CREATE TABLE statement on the database.
        for (int version = 0; version < newVersion; version++) {
          await _performDBUpgrade(db, version + 1);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        for (int version = oldVersion; version < newVersion; version++) {
          await _performDBUpgrade(db, version + 1);
        }
      },
      version: 2,
    );
  }

  static Future<void> _performDBUpgrade(Database db, int version) async {
    switch (version) {
      case 1:
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
      case 2:
        db.execute('''
        ALTER TABLE TrackedData ADD COLUMN altitude_corrected REAL
        ''');
    }
  }
}
