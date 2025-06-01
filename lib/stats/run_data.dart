import 'package:geolocator/geolocator.dart';

class Run {
  int id;
  DateTime startTime;
  int duration;
  double totalDistance;
  int caloriesBurned;
  String weather;
  int? avgHeartRate;
  int? avgStepsPerMin;

  static Run now(int id) {
    return Run(id: id, startTime: DateTime.now());
  }

  Run({
    required this.id,
    required this.startTime,
    this.duration = 0,
    this.totalDistance = 0,
    this.caloriesBurned = 0,
    this.weather = "",
    this.avgHeartRate,
    this.avgStepsPerMin,
  }) {
    startTime ??= DateTime.now();
  }

  factory Run.fromDb(Map<String, dynamic> dbMap) {
    return Run(
      id: dbMap['id'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        dbMap['start_time'] as int,
      ),
      duration: dbMap['duration'] as int,
      totalDistance: dbMap['total_distance'] as double,
      caloriesBurned: dbMap['calories_burned'] as int,
      weather: dbMap['weather'] as String,
      avgHeartRate: dbMap['avg_heart_rate'] as int?,
      avgStepsPerMin: dbMap['avg_steps_per_min'] as int,
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
      "start_time": startTime!.millisecondsSinceEpoch,
      "duration": duration,
      "total_distance": totalDistance,
      "calories_burned": caloriesBurned,
      "weather": weather,
      "avg_heart_rate": avgHeartRate,
      "avg_steps_per_min": avgStepsPerMin,
    };
  }

  TrackedData tdFromPosition(Position pos) {
    return TrackedData.fromPosition(pos, id);
  }

  double avgSpeed() {
    return totalDistance / duration;
  }
}

class TrackedData {
  final int runId;
  int timestamp;
  double latitude;
  double longitude;
  double altitude;
  double gpsAccuracy;
  int? heartRate;
  int? stepsPerMin;

  TrackedData({
    required this.runId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.gpsAccuracy,
    this.heartRate,
    this.stepsPerMin,
  });

  factory TrackedData.fromDb(Map<String, dynamic> dbMap) {
    return TrackedData(
      runId: dbMap['run_id'] as int,
      timestamp: dbMap['timestamp'] as int,
      latitude: dbMap['latitude'] as double,
      longitude: dbMap['longitude'] as double,
      altitude: dbMap['altitude'] as double,
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
    return distanceM(after) / durationS(after);
  }

  TrackedData interpolate(TrackedData other, int ts) {
    if (ts < timestamp || ts > other.timestamp || other.timestamp < timestamp) {
      throw "Cannot interpolate outside of timestamp bounds!";
    }

    final mult = (ts - timestamp) / (other.timestamp - timestamp);
    return TrackedData(
      runId: runId,
      timestamp: ts,
      latitude: _interpolate(latitude, other.latitude, mult),
      longitude: _interpolate(longitude, other.longitude, mult),
      altitude: _interpolate(altitude, other.altitude, mult),
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
            other.latitude == latitude &&
            other.longitude == longitude &&
            other.timestamp == timestamp;

    return areEqual;
  }

  String debug() {
    return "$runId - $gpsAccuracy - $altitude - $latitude - $longitude - $timestamp";
  }

  @override
  int get hashCode =>
      runId.hashCode ^
      gpsAccuracy.hashCode ^
      altitude.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      timestamp.hashCode ^
      heartRate.hashCode ^
      stepsPerMin.hashCode;

  TrackedData withTimestamp(int ts) {
    return TrackedData(runId: runId,
        timestamp: ts,
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        gpsAccuracy: gpsAccuracy);
  }

  double _interpolate(double from, double to, double mult) {
    return from + (to - from) * mult;
  }
}
