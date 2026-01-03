import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:run_log/stats/run_data.dart';

enum _SummaryFields { mapIcon, similar, trace, tags }

class SummaryContainer {
  static int segmentCount = 30;
  Uint8List? mapIcon;
  List<int> similar;
  List<LatLng> trace;
  List<String> tags;

  static SummaryContainer empty() {
    return SummaryContainer.fromJson("{}");
  }

  static SummaryContainer fromJson(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return SummaryContainer(
        map.getUint8List(_SummaryFields.mapIcon.name),
        map.getList<int>(_SummaryFields.similar.name),
        ListPoints.fromDynamicList(map[_SummaryFields.trace.name]),
        map.getList<String>(_SummaryFields.tags.name),
      );
    } catch (e) {
      print("Error: $e");
      return SummaryContainer.empty();
    }
  }

  static SummaryContainer fromData(List<TrackedData> data) {
    var cont = SummaryContainer.empty();
    if (data.length < segmentCount) {
      return cont;
    }
    cont.trace = ListPoints.fromTrackedData(data).trace(segmentCount);
    return cont;
  }

  SummaryContainer(this.mapIcon, this.similar, this.trace, this.tags);

  String toJson() {
    return jsonEncode({
      _SummaryFields.mapIcon.name: mapIcon?.toList(),
      _SummaryFields.similar.name: similar,
      _SummaryFields.trace.name: trace.toList(),
      _SummaryFields.tags.name: tags,
    });
  }

  List<(int, double)> closest(Map<int, List<LatLng>> others) {
    var distances =
        others.entries
            .map((idTr) => (idTr.key, trace.euclidianDistance(idTr.value)))
            .toList();
    distances.sort((a, b) => a.$2.compareTo(b.$2));
    return distances;
  }

  @override
  String toString() {
    return "Summary: $similar, $trace, $tags";
  }

  @override
  bool operator ==(Object other) {
    return other is SummaryContainer &&
        listEquals(other.mapIcon, mapIcon) &&
        listEquals(other.similar, similar) &&
        listEquals(other.trace, trace) &&
        listEquals(other.tags, tags);
  }

  @override
  int get hashCode =>
      mapIcon.hashCode ^ similar.hashCode ^ trace.hashCode ^ tags.hashCode;
}

extension on Map<String, dynamic> {
  List<T> getList<T>(String key, {List<T> defaultValue = const []}) {
    final value = this[key];
    if (value is List) {
      return value.cast<T>().toList();
    }
    return defaultValue;
  }

  Uint8List? getUint8List(String key) {
    final value = this[key];
    if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }
    return null;
  }
}

extension Point on LatLng {
  double distanceEuclidian(LatLng other) {
    final (dx, dy) = (
      (latitude - other.latitude),
      (longitude - other.longitude),
    );
    return dx * dx + dy * dy;
  }

  LatLng add(LatLng other) {
    return LatLng(latitude + other.latitude, longitude + other.longitude);
  }

  LatLng div(double d) {
    return LatLng(latitude / d, longitude / d);
  }
}

extension ListPoints on List<LatLng> {
  static List<LatLng> fromDynamicList(List<dynamic>? list) {
    if (list == null) {
      return [];
    }
    return list.map((item) => LatLng.fromJson(item)).toList();
  }

  static List<LatLng> fromDouble(List<List<double>> list) {
    return list.map((item) => LatLng(item[0], item[1])).toList();
  }

  static List<LatLng> fromTrackedData(List<TrackedData> data) {
    return data.map((d) => LatLng(d.latitude, d.longitude)).toList();
  }

  List<LatLng> trace(int segments) {
    if (length < segments) {
      return List.from(this);
    }
    return List.generate(segments, (seg) {
      final start = length * seg ~/ segments;
      final end = length * (seg + 1) ~/ segments;
      return ListPoints(sublist(start, end)).mean();
    });
  }

  LatLng mean() {
    return reduce((a, b) => (a.add(b))).div(length.toDouble());
  }

  double euclidianDistance(List<LatLng> other) {
    return indexed.fold(0.0, (a, b) => a + b.$2.distanceEuclidian(other[b.$1]));
  }

  List<List<double>> toListDouble() {
    return map((p) => [p.latitude, p.longitude]).toList();
  }

  bool equals(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is List<LatLng> && listEquals(this, other);
  }
}
