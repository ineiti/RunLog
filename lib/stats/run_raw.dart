import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:run_log/stats/filter_data.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/storage.dart';

import 'figures.dart';

enum RRState { waitAccurateGPS, waitRunning, running, paused }

class RunRaw {
  List<TrackedData> rawPositions;
  List<TimeData> runningData = [];
  Figures figures = Figures();
  TrackedData? lastMovement;
  RunStorage? storage;
  Resampler? resampler;
  Run run;
  double minAccuracy = 10;
  double minSpeedStart = 1.75;
  double minSpeedRun = 1;
  bool runPaused = false;

  static Future<RunRaw> newRun(RunStorage storage) async {
    final run = await storage.createRun(DateTime.now());
    return RunRaw(rawPositions: [], run: run, storage: storage);
  }

  static RunRaw loadRun(RunStorage storage, int runId) {
    final run = storage.runs[runId]!;
    final rawPos = storage.trackedData[runId];
    if (rawPos == null) {
      throw ("This run has no data stored");
    }
    return RunRaw(rawPositions: rawPos, run: run, storage: storage);
  }

  RunRaw({required this.rawPositions, required this.run, this.storage}) {
    if (rawPositions.isNotEmpty) {
      for (TrackedData td in rawPositions) {
        _newTracked(td);
      }
    }
  }

  Stream<RRState> continuous(Stream<geo.Position> positions) {
    StreamController<RRState> rrStream = StreamController();

    positions.listen((pos) {
      addPosition(pos);
      rrStream.add(state);
    });

    return rrStream.stream;
  }

  RRState get state {
    if (lastMovement == null) {
      return RRState.waitAccurateGPS;
    }
    if (runningData.isEmpty) {
      return RRState.waitRunning;
    }
    if (runPaused) {
      return RRState.paused;
    }
    return RRState.running;
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

  reset() async {
    rawPositions = [];
    runningData = [];
    lastMovement = null;
    resampler = null;
    run = await storage!.createRun(DateTime.now());
    runPaused = false;
  }

  updateStats() async {
    run.duration = (duration() * 1000).toInt();
    run.totalDistance = distance();
    // print(storage);
    storage!.updateRun(run);
  }

  void figureAddSpeed(int n2) {
    figures.addSpeed(n2);
    figures.updateData(runningData);
  }

  void figureAddAltitude(int n2) {
    figures.addAltitude(n2);
    figures.updateData(runningData);
  }

  void figureAddSlope(int n2) {
    figures.addSlope(n2);
    figures.updateData(runningData);
  }

  void figureAddFigure() {
    figures.addFigure();
  }

  void addPosition(geo.Position pos) {
    final td = run.tdFromPosition(pos);
    rawPositions.add(td);
    storage?.addTrackedData(td);
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
    // print("lastMov: ${lastMovement?.debug()}");
    // print("td: $td");
    final speed = lastMovement!.speedMS(td);
    // print("Speed: $speed");
    final slope =
        (td.altitude - lastMovement!.altitude) /
        lastMovement!.distanceM(td) *
        100;
    lastMovement = td;
    // print("Speed is $speed - length of rawSpeed: ${rawSpeed.length}");

    // Wait for minSpeedStart before starting to record speed.
    if (runningData.isEmpty) {
      if (speed < minSpeedStart) {
        resampler!.pause();
        return;
      }
      runningData.add(TimeData(0, speed, td.altitude, 0));
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
    runningData.add(resampler!.timeData(td.timestamp, speed, td.altitude, slope));
    figures.updateData(runningData);
  }
}

class Resampler {
  int sampleCount = 1;
  int tsReference = -1;
  int sampleInterval;
  TrackedData lastMovement;

  Resampler(this.lastMovement, {this.sampleInterval = 5000}) {
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

  TimeData timeData(int ts, double speed, double altitude, double slope) {
    return TimeData((ts - tsReference) / 1000, speed, altitude, slope);
  }

  pause() {
    tsReference += sampleInterval;
    sampleCount--;
  }
}
