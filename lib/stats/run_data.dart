import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';
import 'package:run_log/stats/conversions.dart';

import '../running/feedback.dart';

class Run {
  int id;
  DateTime startTime;
  int duration;
  double totalDistance;
  int? caloriesBurned;
  String? weather;
  int? avgHeartRate;
  int? avgStepsPerMin;
  FeedbackContainer? feedback;

  static Run now(int id) {
    return Run(id: id, startTime: DateTime.now());
  }

  Run({
    required this.id,
    required this.startTime,
    this.duration = 0,
    this.totalDistance = 0,
    this.caloriesBurned,
    this.weather,
    this.avgHeartRate,
    this.avgStepsPerMin,
    this.feedback,
  });

  factory Run.fromMap(Map<String, dynamic> dbMap) {
    return Run(
      id: dbMap['id'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        dbMap['start_time'] as int,
      ),
      duration: dbMap['duration'] as int,
      totalDistance: dbMap['total_distance'] as double,
      caloriesBurned: dbMap['calories_burned'] as int?,
      weather: dbMap['weather'] as String?,
      avgHeartRate: dbMap['avg_heart_rate'] as int?,
      avgStepsPerMin: dbMap['avg_steps_per_min'] as int?,
      feedback: FeedbackContainer.fromJson(dbMap['feedback'] ?? "{}"),
    );
  }

  factory Run.start(DateTime startTime) {
    return Run(
      id: 0,
      startTime: startTime,
      duration: 0,
      totalDistance: 0,
      caloriesBurned: 0,
      weather: "",
      avgHeartRate: 0,
      avgStepsPerMin: 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      "start_time": startTime.millisecondsSinceEpoch,
      "duration": duration,
      "total_distance": totalDistance,
      "calories_burned": caloriesBurned,
      "weather": weather,
      "avg_heart_rate": avgHeartRate,
      "avg_steps_per_min": avgStepsPerMin,
      "feedback": feedback?.toJson(),
    };
  }

  TrackedData tdFromPosition(Position pos) {
    return TrackedData.fromPosition(pos, id);
  }

  double avgSpeed() {
    return totalDistance / duration * 1000;
  }

  double avgPace(){
    return toPaceMinKm(avgSpeed());
  }

  @override
  String toString() {
    return "$id: $startTime";
  }

  @override
  int get hashCode =>
      id.hashCode ^
      duration.hashCode ^
      totalDistance.hashCode ^
      startTime.hashCode ^
      startTime.hashCode ^
      avgHeartRate.hashCode ^
      avgStepsPerMin.hashCode ^
      caloriesBurned.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Run &&
        other.id == id &&
        other.duration == duration &&
        other.totalDistance == totalDistance &&
        other.startTime == startTime &&
        other.avgHeartRate == avgHeartRate &&
        other.avgStepsPerMin == avgStepsPerMin &&
        other.caloriesBurned == caloriesBurned;
  }
}

class TrackedData {
  int runId;
  int timestamp;
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
    required this.timestamp,
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
      timestamp: dbMap['timestamp'] as int,
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
      timestamp: pos.timestamp.millisecondsSinceEpoch,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      gpsAccuracy: pos.accuracy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "run_id": runId,
      "timestamp": timestamp,
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
    return (timestamp - other.timestamp).abs() / 1000;
  }

  double speedMS(TrackedData after) {
    // print("Calc speed: ${distanceM(after)} / ${durationS(after)}");
    return distanceM(after) / durationS(after);
  }

  TrackedData interpolate(TrackedData other, int ts) {
    if (ts < timestamp || ts > other.timestamp || other.timestamp < timestamp) {
      throw "Cannot interpolate outside of timestamp bounds!";
    }

    final mult = (ts - timestamp) / (other.timestamp - timestamp);
    double? ac;
    if (altitudeCorrected != null && other.altitudeCorrected != null) {
      ac = _interpolate(altitudeCorrected!, other.altitudeCorrected!, mult);
    }
    return TrackedData(
      runId: runId,
      timestamp: ts,
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
        other.timestamp == timestamp;

    return areEqual;
  }

  @override
  String toString() {
    return "$runId - $gpsAccuracy - ${altitude.toStringAsFixed(1)}/${altitudeCorrected?.toStringAsFixed(1)} - ${latitude.toStringAsFixed(6)} - $longitude - ${timestamp ~/ 1000}\n";
  }

  @override
  int get hashCode =>
      runId.hashCode ^
      gpsAccuracy.hashCode ^
      altitude.hashCode ^
      altitudeCorrected.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      timestamp.hashCode ^
      heartRate.hashCode ^
      stepsPerMin.hashCode;

  TrackedData withTimestamp(int ts) {
    return TrackedData(
      runId: runId,
      timestamp: ts,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      altitudeCorrected: altitudeCorrected,
      gpsAccuracy: gpsAccuracy,
    );
  }

  double _interpolate(double from, double to, double mult) {
    return from + (to - from) * mult;
  }
}

extension GpxIO on List<TrackedData> {
  String toGPX() {
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
            time: DateTime.fromMillisecondsSinceEpoch(td.timestamp),
            hdop: td.gpsAccuracy,
          ),
        ).toList();
    return GpxWriter().asString(gpx);
  }

  static List<TrackedData> fromGPX(int runId, String data) {
    final gpxPoints = GpxReader().fromString(data);
    var now = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;
    return gpxPoints.wpts
        .map(
          (wp) => TrackedData(
            runId: runId,
            timestamp: wp.time?.millisecondsSinceEpoch ?? (now += 1000),
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
        .toList();
  }
}
