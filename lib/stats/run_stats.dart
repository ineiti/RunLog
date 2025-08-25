import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:run_log/stats/conversions.dart';
import 'package:run_log/stats/filter_data.dart';
import 'package:run_log/stats/run_data.dart';

import '../running/geotracker.dart';
import '../storage.dart';
import 'figures.dart';

enum RSState { waitAccurateGPS, waitRunning, running, paused }

class RunStats {
  List<TrackedData> rawPositions;
  List<TimeData> runningData = [];
  Figures figures = Figures();
  TrackedData? lastMovement;
  Resampler? resampler;
  Run run;
  double minAccuracy = 10;
  double minSpeedStart = toSpeedMS(8);
  double minSpeedRun = toSpeedMS(16);
  bool runPaused = false;

  static Future<RunStats> newRun(RunStorage storage) async {
    final run = await storage.createRun(DateTime.now());
    return RunStats(rawPositions: [], run: run);
  }

  static Future<RunStats> loadRun(
    RunStorage storage,
    int runId,
    String altitudeURL,
  ) async {
    final run = storage.runs[runId]!;
    final rawPos = await storage.loadTrackedData(runId, altitudeURL);
    return RunStats(rawPositions: rawPos, run: run);
  }

  RunStats({
    required this.rawPositions,
    required this.run,
  }) {
    if (rawPositions.isNotEmpty) {
      for (TrackedData td in rawPositions) {
        _newTracked(td);
      }
      _finalize();
    }
  }

  // Start from the end and remove all points which are slower than
  // `minSpeedRun`.
  _finalize() {
    FilterData speed = FilterData(10);
    speed.update(runningData.speed());
    if (speed.filteredData.isEmpty) {
      return;
    }
    double prev = speed.filteredData.last.y;
    for (int pos = runningData.length - 2; pos >= 0; pos--) {
      var curr = speed.filteredData[pos].y;
      if (curr < minSpeedStart || prev < curr) {
        prev = curr;
        runningData.removeAt(pos + 1);
      } else {
        break;
      }
    }
  }

  RSState get state {
    if (lastMovement == null) {
      return RSState.waitAccurateGPS;
    }
    if (runningData.isEmpty) {
      return RSState.waitRunning;
    }
    if (runPaused) {
      return RSState.paused;
    }
    return RSState.running;
  }

  double duration() {
    if (runningData.isEmpty) {
      return 0;
    }
    return runningData.last.ts;
  }

  double distance() {
    if (resampler == null) {
      return 10;
    }
    // The first element is at t=0 and is only used to make a nice graph.
    return runningData
        .skip(1)
        .fold(0, (dist, e) => dist + e.mps * resampler!.sampleInterval / 1000);
  }

  reset() {
    rawPositions = [];
    runningData = [];
    lastMovement = null;
    resampler = null;
    runPaused = false;
  }

  updateStats() {
    run.duration = (duration() * 1000).toInt();
    run.totalDistance = distance();
  }

  void figureClean() {
    figures.clean();
  }

  void figureAddSpeed(int n2) {
    figures.addSpeed(n2);
  }

  void figureAddAltitude(int n2) {
    figures.addAltitude(n2);
  }

  void figureAddAltitudeCorrected(int n2) {
    figures.addAltitudeCorrected(n2);
  }

  void figureAddSlope(int n2) {
    figures.addSlope(n2);
  }

  void figureAddSlopeStats(int n2) {
    figures.addSlopeStats(n2);
  }

  void figureAddFigure() {
    figures.addFigure();
  }

  void figuresUpdate() {
    figures.updateData(runningData);
  }

  void addPosition(geo.Position pos) {
    final td = run.tdFromPosition(pos);
    rawPositions.add(td);
    updateStats();
    _newTracked(td);
  }

  void _newTracked(TrackedData td) {
    if (resampler == null) {
      if (td.gpsAccuracy < minAccuracy) {
        resampler = Resampler(td);
        lastMovement = td;
      }
      return;
    }

    for (TrackedData step in resampler!.resample(td)) {
      _newResampled(step);
    }
  }

  void _newResampled(TrackedData td) {
    // print("lastMov: $lastMovement");
    // print("td: $td");
    final speed = lastMovement!.speedMS(td);
    // print("Speed: $speed");
    double slope = 100 / lastMovement!.distanceM(td);
    if (td.altitudeCorrected != null &&
        lastMovement!.altitudeCorrected != null) {
      slope *= td.altitudeCorrected! - lastMovement!.altitudeCorrected!;
    } else {
      slope *= td.altitude - lastMovement!.altitude;
    }
    lastMovement = td;
    // print("Speed is $speed - length of rawSpeed: ${rawSpeed.length}");

    // Wait for minSpeedStart before starting to record speed.
    if (runningData.isEmpty) {
      if (speed < minSpeedStart) {
        resampler!.pause();
        return;
      }
      runningData.add(TimeData(0, speed, td.altitude, td.altitudeCorrected, 0));
      run.startTime = DateTime.fromMillisecondsSinceEpoch(
        td.timestamp - resampler!.sampleInterval,
      );
    }

    // If running speed is below minSpeedRun, don't count the interval
    // and don't add it to rawSpeed.
    // TODO: the pauses could be shown in the figure.
    runPaused = speed < minSpeedRun;
    if (runPaused) {
      resampler!.pause();
      return;
    }
    runningData.add(
      resampler!.timeData(
        td.timestamp,
        speed,
        td.altitude,
        td.altitudeCorrected,
        slope,
      ),
    );
    figures.updateData(runningData);
  }
}

class Resampler {
  int sampleCount = 1;
  int tsReference = -1;
  int sampleInterval;
  TrackedData lastMovement;

  Resampler(
    this.lastMovement, {
    this.sampleInterval = GeoTracker.intervalSeconds * 1000,
  }) {
    tsReference = lastMovement.timestamp;
  }

  List<TrackedData> resample(TrackedData td) {
    if (lastMovement == td) {
      throw "Cannot resample with same element again";
    }
    List<TrackedData> resampled = [];
    while (nextSample <= td.timestamp) {
      resampled.add(lastMovement.interpolate(td, nextSample));
      sampleCount++;
    }

    lastMovement = td;
    return resampled;
  }

  int get nextSample => tsReference + sampleCount * sampleInterval;

  TimeData timeData(
    int ts,
    double speed,
    double altitude,
    double? altitudeCorrected,
    double slope,
  ) {
    return TimeData(
      (ts - tsReference) / 1000,
      speed,
      altitude,
      altitudeCorrected,
      slope,
    );
  }

  pause() {
    tsReference += sampleInterval;
    sampleCount--;
  }
}
