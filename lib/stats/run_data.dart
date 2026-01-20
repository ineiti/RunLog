import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import 'package:run_log/stats/run_stats.dart';
import 'package:run_log/storage.dart';
import 'package:run_log/summary/summary.dart';

import '../stats/conversions.dart';
import '../feedback/feedback.dart';

class Run {
  int id;
  DateTime startTime;
  int durationMS;
  double totalDistanceM;
  int? caloriesBurned;
  String? weather;
  int? avgHeartRate;
  int? avgStepsPerMin;
  FeedbackContainer? feedback;
  SummaryContainer? summary;

  static Run now(int id) {
    return Run(id: id, startTime: DateTime.now());
  }

  Run({
    required this.id,
    required this.startTime,
    this.durationMS = 0,
    this.totalDistanceM = 0,
    this.caloriesBurned,
    this.weather,
    this.avgHeartRate,
    this.avgStepsPerMin,
    this.feedback,
    this.summary,
  });

  factory Run.fromMap(Map<String, dynamic> dbMap) {
    return Run(
      id: dbMap['id'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        dbMap['start_time'] as int,
      ),
      durationMS: dbMap['duration'] as int,
      totalDistanceM: dbMap['total_distance'] as double,
      caloriesBurned: dbMap['calories_burned'] as int?,
      weather: dbMap['weather'] as String?,
      avgHeartRate: dbMap['avg_heart_rate'] as int?,
      avgStepsPerMin: dbMap['avg_steps_per_min'] as int?,
      feedback: FeedbackContainer.fromJson(dbMap['feedback'] ?? "{}"),
      summary: SummaryContainer.fromJson(dbMap['summary'] ?? "{}"),
    );
  }

  factory Run.start(DateTime startTime) {
    return Run(
      id: 0,
      startTime: startTime,
      durationMS: 0,
      totalDistanceM: 0,
      caloriesBurned: 0,
      weather: "",
      avgHeartRate: 0,
      avgStepsPerMin: 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      "start_time": startTime.millisecondsSinceEpoch,
      "duration": durationMS,
      "total_distance": totalDistanceM,
      "calories_burned": caloriesBurned,
      "weather": weather,
      "avg_heart_rate": avgHeartRate,
      "avg_steps_per_min": avgStepsPerMin,
      "feedback": feedback?.toJson(),
      "summary": summary?.toJson(),
    };
  }

  TrackedData tdFromPosition(Position pos) {
    return TrackedData.fromPosition(pos, id);
  }

  double avgSpeed() {
    if (durationMS > 0) {
      return totalDistanceM / (durationMS / 1000);
    } else {
      return 0;
    }
  }

  double avgPace() {
    return toPaceMinKm(avgSpeed());
  }

  Future<void> ensureStats(RunStorage rs) async {
    if (durationMS == 0 || totalDistanceM == 0) {
      await updateStats(rs);
    }
  }

  Future<void> updateStats(RunStorage rs) async {
    final td = await rs.loadTrackedData(id);
    final stats = RunStats(td, this);
    durationMS = (stats.durationSec() * 1000).toInt();
    totalDistanceM = stats.distanceM();
    await rs.updateRun(this);
  }

  @override
  String toString() {
    return "$id: $startTime";
  }

  @override
  int get hashCode =>
      id.hashCode ^
      durationMS.hashCode ^
      totalDistanceM.hashCode ^
      startTime.hashCode ^
      startTime.hashCode ^
      avgHeartRate.hashCode ^
      avgStepsPerMin.hashCode ^
      caloriesBurned.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Run &&
        other.id == id &&
        other.durationMS == durationMS &&
        other.totalDistanceM == totalDistanceM &&
        other.startTime == startTime &&
        other.avgHeartRate == avgHeartRate &&
        other.avgStepsPerMin == avgStepsPerMin &&
        other.caloriesBurned == caloriesBurned;
  }
}

class TrackedData {
  int runId;
  int timestampMS;
  double latitude;
  double longitude;
  double altitude;
  double gpsAccuracy;
  double? altitudeCorrected;
  int? heartRate;
  int? stepsPerMin;
  int? id;

  TrackedData({
    required this.runId,
    required this.timestampMS,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.gpsAccuracy,
    this.altitudeCorrected,
    this.heartRate,
    this.stepsPerMin,
    this.id,
  });

  factory TrackedData.fromMap(Map<String, dynamic> dbMap) {
    return TrackedData(
      id: dbMap['id'] as int,
      runId: dbMap['run_id'] as int,
      timestampMS: dbMap['timestamp'] as int,
      latitude: dbMap['latitude'] as double,
      longitude: dbMap['longitude'] as double,
      altitude: dbMap['altitude'] as double,
      altitudeCorrected: dbMap['altitude_corrected'] as double?,
      gpsAccuracy: dbMap['gps_accuracy'] as double,
      heartRate: dbMap['heart_rate'] as int?,
      stepsPerMin: dbMap['steps_per_min'] as int?,
    );
  }

  factory TrackedData.fromPosition(Position pos, int runId) {
    return TrackedData(
      runId: runId,
      timestampMS: pos.timestamp.millisecondsSinceEpoch,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      gpsAccuracy: pos.accuracy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "run_id": runId,
      "timestamp": timestampMS,
      "latitude": latitude,
      "longitude": longitude,
      "altitude": altitude,
      "altitude_corrected": altitudeCorrected,
      "gps_accuracy": gpsAccuracy,
      "heart_rate": heartRate,
      "steps_per_min": stepsPerMin,
    };
  }

  double distanceM(TrackedData other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  double durationS(TrackedData other) {
    return (timestampMS - other.timestampMS).abs() / 1000;
  }

  double speedMS(TrackedData after) {
    return distanceM(after) / durationS(after);
  }

  double bestAltitude() {
    return altitudeCorrected ?? altitude;
  }

  double bestSlopeFrom(TrackedData other) {
    double slope = 100 / other.distanceM(this);
    return slope * (bestAltitude() - other.bestAltitude());
  }

  TrackedData interpolate(TrackedData other, int ts) {
    if (ts < timestampMS ||
        ts > other.timestampMS ||
        other.timestampMS < timestampMS) {
      throw "Cannot interpolate outside of timestamp bounds!";
    }

    final mult = (ts - timestampMS) / (other.timestampMS - timestampMS);
    double? ac;
    if (altitudeCorrected != null && other.altitudeCorrected != null) {
      ac = _interpolate(altitudeCorrected!, other.altitudeCorrected!, mult);
    }
    return TrackedData(
      runId: runId,
      timestampMS: ts,
      latitude: _interpolate(latitude, other.latitude, mult),
      longitude: _interpolate(longitude, other.longitude, mult),
      altitude: _interpolate(altitude, other.altitude, mult),
      altitudeCorrected: ac,
      gpsAccuracy: _interpolate(gpsAccuracy, other.gpsAccuracy, mult),
    );
  }

  @override
  bool operator ==(Object other) {
    var areEqual =
        other is TrackedData &&
        other.runId == runId &&
        other.gpsAccuracy == gpsAccuracy &&
        other.altitude == altitude &&
        other.altitudeCorrected == altitudeCorrected &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestampMS == timestampMS;

    return areEqual;
  }

  @override
  String toString() {
    return "$runId - $gpsAccuracy - ${altitude.toStringAsFixed(1)}/${altitudeCorrected?.toStringAsFixed(1)} - ${latitude.toStringAsFixed(6)} - $longitude - ${timestampMS ~/ 1000}\n";
  }

  @override
  int get hashCode =>
      runId.hashCode ^
      gpsAccuracy.hashCode ^
      altitude.hashCode ^
      altitudeCorrected.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      timestampMS.hashCode ^
      heartRate.hashCode ^
      stepsPerMin.hashCode;

  TrackedData withTimestamp(int ts) {
    return TrackedData(
      runId: runId,
      timestampMS: ts,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      altitudeCorrected: altitudeCorrected,
      gpsAccuracy: gpsAccuracy,
    );
  }

  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }

  double _interpolate(double from, double to, double mult) {
    return from + (to - from) * mult;
  }
}

extension ListLatLng on List<TrackedData> {
  List<LatLng> toLatLng() {
    return map((ll) => LatLng(ll.latitude, ll.longitude)).toList();
  }
}

extension GpxIO on List<TrackedData> {
  String toGPX(FeedbackContainer? feedback) {
    var gpx = Gpx();
    gpx.creator = "RunLog";
    gpx.wpts =
        map(
          (td) => Wpt(
            lat: td.latitude,
            lon: td.longitude,
            ele: td.altitude,
            extensions:
                td.altitudeCorrected == null
                    ? null
                    : {"altitudeCorrected": td.altitudeCorrected!},
            time: DateTime.fromMillisecondsSinceEpoch(td.timestampMS),
            hdop: td.gpsAccuracy,
          ),
        ).toList();
    if (feedback != null) {
      gpx.extensions["FeedbackContainer"] = feedback.toJson();
    }
    return GpxWriter().asString(gpx);
  }

  static (List<TrackedData>, FeedbackContainer?) fromGPX(
    int runId,
    String data,
  ) {
    final gpxPoints = GpxReader().fromString(data);
    final feedbackJson = gpxPoints.extensions["FeedbackContainer"];
    FeedbackContainer? feedbackContainer;
    if (feedbackJson != null) {
      try {
        feedbackContainer = FeedbackContainer.fromJson(feedbackJson as String);
      } catch (e) {
        print("Couldn't get FeedbackContainer: $e");
      }
    }
    var now = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;
    return (
      gpxPoints.wpts
          .map(
            (wp) => TrackedData(
              runId: runId,
              timestampMS: wp.time?.millisecondsSinceEpoch ?? (now += 1000),
              latitude: wp.lat ?? 0,
              longitude: wp.lon ?? 0,
              altitude: wp.ele ?? 0,
              // This is not completely correct, but not too bad either...
              altitudeCorrected: double.tryParse(
                wp.extensions["altitudeCorrected"].toString(),
              ),
              gpsAccuracy: wp.hdop ?? 0,
            ),
          )
          .toList(),
      feedbackContainer,
    );
  }
}
