import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:run_log/stats/filter_speed.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/storage.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

enum RRState { waitAccurateGPS, waitRunning, running, paused }

class RunRaw {
  List<TrackedData> rawPositions;
  List<TimeData> rawSpeed = [];
  List<FilterSpeed> filters = [];
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
    if (rawSpeed.isEmpty) {
      return RRState.waitRunning;
    }
    if (runPaused) {
      return RRState.paused;
    }
    return RRState.running;
  }

  double duration() {
    if (rawSpeed.isEmpty) {
      return 0;
    }
    return rawSpeed.last.dt;
  }

  double distance() {
    if (resampler == null) {
      return 10;
    }
    // The first element is at t=0 and is only used to make a nice graph.
    return rawSpeed
        .skip(1)
        .fold(0, (dist, e) => dist + e.mps * resampler!.sampleInterval / 1000);
  }

  reset() async {
    rawPositions = [];
    rawSpeed = [];
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

  void addPosition(geo.Position pos) {
    final td = run.tdFromPosition(pos);
    rawPositions.add(td);
    storage?.addTrackedData(td);
    updateStats();
    _newTracked(td);
  }

  void addFilter(int n2) {
    var filter = FilterSpeed(n2);
    filter.update(rawSpeed);
    filters.add(filter);
  }

  Widget runStats() {
    print("RawSpeed.length: ${rawSpeed.length}");
    if (rawSpeed.isEmpty){
      return Text("No data yet");
    }
    var (minSpeed, maxSpeed) = (rawSpeed.minSpeed(), rawSpeed.maxSpeed());
    var lines = [
      LineSeries<TimeData, String>(
        dataSource: rawSpeed,
        animationDuration: 500,
        xValueMapper: (TimeData entry, _) => _timeHMS(entry.dt),
        yValueMapper: (TimeData entry, _) => _speedMinKm(entry.mps),
        name: 'Raw [min/km]',
        dataLabelSettings: DataLabelSettings(isVisible: false),
      ),
    ];
    for (var filter in filters) {
      print("Filter.length: ${filter.filteredSpeed.length}");
      if (filter.filteredSpeed.isEmpty){
        return Text("No filter data yet");
      }
      minSpeed = math.min(minSpeed, filter.filteredSpeed.minSpeed());
      maxSpeed = math.max(maxSpeed, filter.filteredSpeed.maxSpeed());
      lines.add(
        LineSeries<TimeData, String>(
          animationDuration: 500,
          dataSource: filter.filteredSpeed,
          xValueMapper: (TimeData entry, _) => _timeHMS(entry.dt),
          yValueMapper: (TimeData entry, _) => _speedMinKm(entry.mps),
          name: 'Filter ${filter.lanczos.length * 5}s',
          dataLabelSettings: DataLabelSettings(isVisible: false),
        ),
      );
    }
    var (minPace, maxPace) = (
    (_speedMinKm(maxSpeed) * 6 - 1).toInt() / 6,
    (_speedMinKm(minSpeed) * 6 + 1).toInt() / 6,
    );
    var med = (maxPace + minPace) / 2;
    if (med + 0.5 > maxPace) {
      maxPace = med + 0.5;
    }
    if (med - 0.5 < minPace) {
      minPace = med - 0.5;
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: SfCartesianChart(
        zoomPanBehavior: ZoomPanBehavior(
          enablePinching: true,
          enablePanning: true,
          enableDoubleTapZooming: true,
          enableSelectionZooming: true,
          enableMouseWheelZooming: true,
          zoomMode: ZoomMode.x,
        ),
        primaryXAxis: CategoryAxis(
          labelIntersectAction: AxisLabelIntersectAction.multipleRows,
        ),
        primaryYAxis: NumericAxis(
          isInversed: true,
          minimum: minPace,
          maximum: maxPace,
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            final value = double.parse(details.text);
            final min = value.toInt();
            final sec = ((value - min) * 60).round();
            if (sec == 0) {
              return ChartAxisLabel("$min'", details.textStyle);
            } else {
              return ChartAxisLabel("$min' $sec''", details.textStyle);
            }
          },
        ),
        legend: Legend(isVisible: true),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: lines,
      ),
    );
  }

  String _timeHMS(double s) {
    final hours = (s / 60 / 60).toInt();
    final mins = (s / 60 % 60).toInt();
    final sec = (s % 60).toInt();
    if (hours > 0) {
      return "${hours}h ${mins}m ${sec}s";
    } else if (mins > 0) {
      return "${mins}m ${sec}s";
    } else {
      return "${sec}s";
    }
  }

  double _speedMinKm(double mps) {
    if (mps <= 0) {
      return mps;
    }
    return 1000 / 60 / mps;
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
    // print("td: ${td.debug()}");
    final speed = lastMovement!.speedMS(td);
    lastMovement = td;
    // print("Speed is $speed - length of rawSpeed: ${rawSpeed.length}");

    // Wait for minSpeedStart before starting to record speed.
    if (rawSpeed.isEmpty) {
      if (speed < minSpeedStart) {
        resampler!.pause();
        return;
      }
      rawSpeed.add(TimeData(0, speed));
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
    rawSpeed.add(resampler!.timeData(td.timestamp, speed));
    for (var filter in filters) {
      filter.update(rawSpeed);
      print("${rawSpeed.length} - ${filter.filteredSpeed.length}");
    }
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

  TimeData timeData(ts, speed) {
    return TimeData((ts - tsReference) / 1000, speed);
  }

  pause() {
    tsReference += sampleInterval;
    sampleCount--;
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

  double maxSpeed() {
    return reduce((a, b) => a.mps > b.mps ? a : b).mps;
  }

  double minSpeed() {
    return reduce((a, b) => a.mps < b.mps ? a : b).mps;
  }
}
