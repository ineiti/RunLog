import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/storage.dart';

enum RRState { waitAccurateGPS, waitRunning, running, paused }

class RunRaw {
  List<TrackedData> rawPositions;
  List<TimeData> rawSpeed = [];
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
    final run = storage.runs.firstWhere((r) => r.id == runId);
    final rawPos = storage.trackedData[runId];
    if (rawPos == null) {
      throw ("This run has no data stored");
    }
    return RunRaw(rawPositions: rawPos, run: run, storage: storage);
  }

  RunRaw({required this.rawPositions, required this.run, this.storage}) {
    if (rawPositions.isNotEmpty) {}
  }

  Stream<RRState> continuous(Stream<Position> positions) {
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
    if (rawSpeed.isEmpty) {
      return RRState.waitRunning;
    }
    if (rawPositions.last != lastMovement) {
      return RRState.paused;
    }
    return RRState.running;
  }

  double minSpeed() {
    return rawSpeed.reduce((a, b) => a.mps > b.mps ? a : b).mps;
  }

  double maxSpeed() {
    return rawSpeed.reduce((a, b) => a.mps < b.mps ? a : b).mps;
  }

  double duration() {
    if (rawSpeed.isEmpty) {
      return 0;
    }
    return rawSpeed.last.dt;
  }

  double distance() {
    if (resampler == null) {
      return 0;
    }
    return rawSpeed.fold(
      0,
      (dist, e) => dist + e.mps * resampler!.sampleInterval,
    );
  }

  reset() async {
    rawPositions = [];
    rawSpeed = [];
    lastMovement = null;
    resampler = null;
    run = await storage!.createRun(DateTime.now());
    runPaused = false;
  }

  save() async {
    run.duration = (duration() * 1000).toInt();
    run.totalDistance = distance();
    storage!.updateRun(run);
  }

  void addPosition(Position pos) {
    final td = run.tdFromPosition(pos);
    rawPositions.add(td);
    storage?.addTrackedData(td);
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
    final speed = lastMovement!.speedMS(td);

    // Wait for minSpeedStart before starting to record speed.
    if (rawSpeed.isEmpty) {
      if (speed < minSpeedStart) {
        return;
      }
      resampler!.sampleReference = lastMovement!.timestamp;
      rawSpeed.add(TimeData(0, speed));
      run.startTime = DateTime.fromMillisecondsSinceEpoch(td.timestamp);
    }

    // If running speed is below minSpeedRun, don't count the interval
    // and don't add it to rawSpeed.
    // TODO: the pauses could be shows in the figure.
    runPaused = speed < minSpeedRun;
    if (runPaused) {
      resampler!.sampleReference += resampler!.sampleInterval;
      return;
    }
    rawSpeed.add(resampler!.calcSpeed(lastMovement!, td));
  }
}

class Resampler {
  int sampleReference = -1;
  int sampleInterval;
  TrackedData lastMovement;

  Resampler(this.lastMovement, {this.sampleInterval = 5000}) {
    sampleReference = lastMovement.timestamp;
  }

  List<TrackedData> resample(TrackedData td) {
    if (lastMovement == td){
      throw "Cannot resample with same element again";
    }
    List<TrackedData> resampled = [];
    while (sampleReference <= td.timestamp) {
      resampled.add(lastMovement.interpolate(td, sampleReference));
      sampleReference += sampleInterval;
    }

    lastMovement = td;
    return resampled;
  }

  TimeData calcSpeed(TrackedData from, TrackedData to) {
    return TimeData((to.timestamp - sampleReference) / 1000, from.speedMS(to));
  }
}

class TimeData implements Comparable<TimeData> {
  TimeData(this.dt, this.mps);

  final double dt;
  final double mps;

  @override
  int compareTo(TimeData other) {
    throw mps.compareTo(other.mps);
  }
}

extension DebugPrint on List<TimeData> {
  /// Prints each element with its index (for debugging)
  String debug() {
    if (isEmpty) {
      return 'List is empty';
    }
    return map(
      (td) => "(${td.dt.toStringAsFixed(1)}, ${td.mps.toStringAsFixed(1)})",
    ).join(", ");
  }
}
