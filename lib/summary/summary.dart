import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:run_log/stats/run_data.dart';

enum _SummaryFields { mapIcon, similar, trace, tags }

class SummaryContainer {
  static int segmentCount = 30;
  Uint8List? mapIcon;
  List<int> similar;
  ListPoints trace;
  List<String> tags;

  static SummaryContainer empty() {
    return SummaryContainer.fromJson("{}");
  }

  static SummaryContainer fromJson(String s) {
    final map = jsonDecode(s) as Map<String, dynamic>;
    return SummaryContainer(
      map.getUint8List(_SummaryFields.mapIcon.name),
      map.getList<int>(_SummaryFields.similar.name),
      ListPoints.fromDynamicList(map[_SummaryFields.trace.name]),
      map.getList<String>(_SummaryFields.tags.name),
    );
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

  List<(int, double)> closest(List<Run> others) {
    var distances =
        others
            .map(
              (o) => (o.id, o.summary?.trace.euclidianDistance(trace) ?? 1000),
            )
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
        other.trace == trace &&
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

class Point {
  double x;
  double y;

  static Point fromDynamic(List<dynamic> xy) {
    return Point((xy[0] as num).toDouble(), (xy[1] as num).toDouble());
  }

  Point(this.x, this.y);

  double distanceEuclidian(Point other) {
    return (x - other.x) * (x - other.x) + (y - other.y) * (y - other.y);
  }

  Point add(other) {
    return Point(x + other.x, y + other.y);
  }

  Point div(double d) {
    return Point(x / d, y / d);
  }

  @override
  String toString() {
    return "[$x, $y]";
  }

  @override
  bool operator ==(Object other) {
    return other is Point && x == other.x && y == other.y;
  }

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class ListPoints {
  List<Point> points;

  static ListPoints fromDynamicList(List<dynamic>? list) {
    if (list == null) {
      return ListPoints([]);
    }

    return ListPoints(list.map((item) => Point.fromDynamic(item)).toList());
  }

  static ListPoints fromTrackedData(List<TrackedData> data) {
    return ListPoints(data.map((d) => Point(d.latitude, d.longitude)).toList());
  }

  ListPoints(this.points);

  ListPoints trace(int segments) {
    if (points.length < segments) {
      return ListPoints(List.from(points));
    }
    return ListPoints(
      List.generate(segments, (seg) {
        final start = points.length * seg ~/ segments;
        final end = points.length * (seg + 1) ~/ segments;
        return ListPoints(points.sublist(start, end)).mean();
      }),
    );
  }

  Point mean() {
    return points.reduce((a, b) => (a.add(b))).div(points.length.toDouble());
  }

  double euclidianDistance(ListPoints other) {
    return points.indexed.fold(
      0.0,
      (a, b) => a + b.$2.distanceEuclidian(other.points[b.$1]),
    );
  }

  List<List<double>> toList() {
    return points.map((p) => [p.x, p.y]).toList();
  }

  @override
  bool operator ==(Object other) {
    return other is ListPoints && listEquals(other.points, points);
  }

  @override
  int get hashCode => points.hashCode;

  @override
  String toString() {
    return "$points";
  }
}
