import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:run_log/feedback/feedback.dart';
import 'package:sqflite/sqflite.dart';

import '../../stats/run_data.dart';

class RunStorage {
  static var dbName = "running_log.db";
  StreamController<void> updateRuns = StreamController.broadcast();
  late Database db;
  Map<int, Run> runs = {};
  Map<int, List<TrackedData>> trackedData = {};

  RunStorage._(this.db);

  // Factory constructor to handle async initialization
  static Future<RunStorage> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final rs = RunStorage._(await _getDB());
    return rs;
  }

  static Future<RunStorage> initLoad() async {
    final rs = await init();
    await rs.loadRuns();
    return rs;
  }

  static Future<RunStorage> initClean() async {
    final rs = await init();
    await rs.cleanDB();
    return rs;
  }

  Future<void> loadRuns() async {
    final runMaps = await db.query('Runs');
    final runList = runMaps.map((map) => Run.fromMap(map)).toList();
    for (var run in runList) {
      await run.ensureStats(this);
      runs[run.id] = run;
    }

    updateRuns.add([]);
  }

  Future<List<TrackedData>> loadTrackedData(int runId) async {
    if (trackedData.containsKey(runId)) {
      return trackedData[runId]!;
    }

    final trackedDataMaps = await db.query(
      'TrackedData',
      where: "run_id = ?",
      whereArgs: [runId],
    );
    trackedData[runId] =
        trackedDataMaps.map((map) => TrackedData.fromMap(map)).toList();

    return trackedData[runId]!;
  }

  Future<List<TrackedData>> updateHeightData(
    int runId,
    String altitudeURL,
    void Function(int, int)? state,
  ) async {
    final allTrackedData = await loadTrackedData(runId);
    // Update trackedData with real altitude reading, if available
    final List<int> tdUpdate = [];
    for (int i = 0; i < allTrackedData.length; i++) {
      if (allTrackedData[i].altitudeCorrected == null) {
        tdUpdate.add(i);
      }
      if (tdUpdate.length >= 100) {
        if (state != null) {
          state(i ~/ 100, allTrackedData.length ~/ 100);
        }
        await _updateTrackedData(allTrackedData, tdUpdate, altitudeURL);
        tdUpdate.clear();
      }
    }
    await _updateTrackedData(allTrackedData, tdUpdate, altitudeURL);

    if (state != null) {
      state(0, 0);
    }

    return allTrackedData;
  }

  Future<List<TrackedData>> clearHeightData(int runId) async {
    final allTrackedData = await loadTrackedData(runId);
    await db.transaction((txn) async {
      for (var td in allTrackedData) {
        td.altitudeCorrected = null;
        await _updateTD(txn, td);
      }
    });
    return allTrackedData;
  }

  Future<String> exportAll() async {
    List<Map<String, dynamic>> content = [];
    for (var run in runs.entries) {
      final track = await loadTrackedData(run.key);
      content.add({
        'run': run.value.toMap(),
        'track': track.map((t) => t.toMap()).toList(),
      });
    }
    return jsonEncode(content);
  }

  importAll(String content) async {
    final decoded = jsonDecode(content) as List<dynamic>;
    for (var entry in decoded) {
      entry["run"]["id"] = -1;
      final runJson = Run.fromMap(entry["run"]);
      final run = await _addRun(runJson);
      runs[run.id] = run;
      final trackedJson =
          (entry["track"] as List<dynamic>).map((t) {
            t["id"] = -1;
            return TrackedData.fromMap(t);
          }).toList();
      trackedData[run.id] = [];
      for (var track in trackedJson) {
        track.runId = run.id;
        await addTrackedData(track);
      }
      updateRuns.add([]);
    }
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
      await db.transaction((txn) async {
        if (acs.length == tdUpdate.length) {
          for (int i in tdUpdate) {
            allTrackedData[i].altitudeCorrected = acs.removeAt(0);
            await _updateTD(txn, allTrackedData[i]);
          }
        }
      });
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
        return [];
      }
    } else {
      print("Error while getting heights, status-code is: ${response.statusCode}");
      throw Exception('Failed to load data');
    }
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

  Future<void> updateRun(Run run) async {
    await db.update('Runs', run.toMap(), where: "id = ?", whereArgs: [run.id]);
    runs[run.id] = run;
  }

  _updateTD(DatabaseExecutor db, TrackedData td) async {
    await db.update(
      'TrackedData',
      td.toMap(),
      where: "id = ?",
      whereArgs: [td.id],
    );
  }

  cleanDB() async {
    db.delete('Runs');
    db.delete('TrackedData');
    db.delete('sqlite_sequence');
    runs = {};
    trackedData = {};
  }

  @override
  String toString() {
    return "Storage(${identityHashCode(this)}) - $runs";
  }

  static Future<String> _dbPath() async {
    return join(await getDatabasesPath(), dbName);
  }

  static Future<Database> _getDB() async {
    return await openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await _dbPath()),
      onCreate: (db, newVersion) async {
        print("Creating db");
        // Run the CREATE TABLE statement on the database.
        for (int version = 0; version < newVersion; version++) {
          await _performDBUpgrade(db, version + 1);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        print("Upgrading from $oldVersion to $newVersion");
        for (int version = oldVersion; version < newVersion; version++) {
          await _performDBUpgrade(db, version + 1);
        }
      },
      version: 4,
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
      case 3:
        db.execute('''
        ALTER TABLE Runs ADD COLUMN feedback TEXT
        ''');
      case 4:
        db.execute('''
        ALTER TABLE Runs ADD COLUMN summary TEXT
        ''');
    }
  }
}

class DebugStorage {
  static dbPrefill(
    RunStorage rs,
    Duration before,
    int points,
    List<double> speeds,
    List<double> altitudes,
    FeedbackContainer? feedback,
  ) async {
    var runStart = DateTime.now().subtract(before);
    // This is for the tests, as encoding/decoding a DateTime messes up with
    // the milliseconds and microseconds.
    runStart = runStart.subtract(Duration(microseconds: runStart.microsecond));
    runStart = runStart.subtract(Duration(milliseconds: runStart.millisecond));
    var run = await rs.createRun(runStart);
    run.feedback = feedback;
    final track = _createTracker(
      run.id,
      run.startTime,
      points,
      speeds,
      altitudes,
    );
    for (var td in track) {
      await rs.addTrackedData(td);
    }
    run.durationMS = track.last.timestampMS - track.first.timestampMS;
    run.totalDistanceM = track.last.latitude * 6e6 / 180 * pi;
    await rs.updateRun(run);
  }

  static List<TrackedData> _createTracker(
    int id,
    DateTime start,
    int points,
    List<double> speed,
    List<double> altitude,
  ) {
    final speeds = _cosSeries(points, speed);
    final distances = _integrateList(speeds);
    final altitudes = _cosSeries(points, altitude);
    return List.generate(
      points,
      (i) => TrackedData(
        runId: id,
        timestampMS: start.millisecondsSinceEpoch + i * 1000,
        latitude: distances[i] / 6e6 / pi * 180,
        longitude: 0,
        altitude: altitudes[i],
        altitudeCorrected: altitudes[i],
        gpsAccuracy: 5,
      ),
    );
  }

  static List<double> _integrateList(List<double> list) {
    List<double> result = [];
    double sum = 0;
    for (var num in list) {
      sum += num;
      result.add(sum);
    }
    return result;
  }

  static List<double> _cosSeries(int points, List<double> arg) {
    return List.generate(
      points,
      (i) => arg.asMap().entries.fold(
        0,
        (prev, s) => prev + s.value * cos(s.key * i / points * 2 * pi),
      ),
    );
  }
}
