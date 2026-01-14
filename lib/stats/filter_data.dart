import 'dart:math';

import 'package:run_log/feedback/tones.dart';

class FilterData {
  List<TimeData> filteredData = [];
  List<TimeData> rawData = [];
  late TimeData tdMin;
  late TimeData tdMax;
  int maxSize = 0;
  final List<List<double>> _minMax = [];
  late Filter _filter;

  static FilterData subSampled(int filterN2, int maxSize) {
    var fd = FilterData(filterN2);
    fd.maxSize = maxSize;
    return fd;
  }

  FilterData(int filterN2) {
    _filter = Filter(filterN2);
    _resetMM();
  }

  void setFilter(int filterN2){
    _filter = Filter(filterN2);
    _filterData();
  }

  void add(TimeData raw) {
    rawData.add(raw);
  }

  void replace(List<TimeData> raw) {
    rawData = raw;
    _filterData();
  }

  int length() {
    return _filter.lanczos.length;
  }

  void _filterData() {
    _minMax.clear();
    filteredData = ListData.fromDoubles(
      rawData.map((s) => s.ts).toList().partial(maxSize),
      _filterMinMax(rawData.map((s) => s.mps).toList()),
      _filterMinMax(rawData.map((s) => s.altitude).toList()),
      _filterMinMax(rawData.map((s) => s.slope).toList()),
      _filterMinMax(rawData.map((s) => s.altitudeCorrected).toList()),
      _filterMinMax(rawData.map((s) => s.targetPace).toList()),
    );
    tdMin = TimeData(
      0,
      _minMax[0][0],
      _minMax[1][0],
      _minMax[2][0],
      _minMax[3][0],
      _minMax[4][0],
    );
    tdMax = TimeData(
      0,
      _minMax[0][1],
      _minMax[1][1],
      _minMax[2][1],
      _minMax[3][1],
      _minMax[4][1],
    );
  }

  void _resetMM() {
    tdMin = TimeData.init(double.infinity);
    tdMax = TimeData.init(-double.infinity);
  }

  List<double> _filterMinMax(List<double?> values) {
    final filtered = _filter.apply(
      values.where((v) => v != null).map((v) => v!).toList(),
      maxSize,
    );
    _minMax.add([_filter.min, _filter.max]);
    return filtered;
  }
}

class Filter {
  double min = double.infinity;
  double max = -double.infinity;
  late List<double> lanczos;

  Filter(int filterN2) {
    lanczos = _lanczos(filterN2);
  }

  void resetMinMax() {
    min = double.infinity;
    max = -double.infinity;
  }

  List<double> apply(List<double> values, int? maxLength) {
    resetMinMax();
    return values.indexed
        .map((iv) => applyLanczos(values, iv.$1))
        .toList()
        .partial(maxLength);
  }

  // Applies the lanczos filter to 'values' and keeps the peak at 'pos'.
  // If the lanczos filter doesn't fit, it will be cut and thus not return
  // a nice sampling window.
  double applyLanczos(List<double> values, int pos) {
    if (pos < 0 || pos >= values.length) {
      throw ("pos out of range");
    }
    // This works because lanczos.length is always an odd number.
    int valuesStart = pos - lanczos.length ~/ 2;
    int valuesEnd = pos + lanczos.length ~/ 2;
    int lanczosStart = 0;
    int lanczosEnd = lanczos.length - 1;
    if (valuesStart < 0) {
      lanczosStart -= valuesStart;
      valuesStart = 0;
    }
    if (valuesEnd >= values.length) {
      final overflow = valuesEnd - values.length + 1;
      lanczosEnd -= overflow;
      valuesEnd -= overflow;
    }

    final filter = lanczos.sublist(lanczosStart, lanczosEnd + 1);
    final src = values.sublist(valuesStart, valuesEnd + 1);

    double sum = filter.fold(0.0, (a, b) => a + b);
    if (sum == 0) {
      return 0;
    }
    final value = src.asMap().entries.fold(
      0.0,
      (a, b) => a + b.value * filter[b.key] / sum,
    );

    min = min < value ? min : value;
    max = max > value ? max : value;
    return value;
  }

  static List<double> _lanczos(int n2) {
    if (n2 == 0) {
      return [1];
    }
    return List.generate(n2 * 2 + 1, (n) => _sinc(2 * n / (2 * n2) - 1));
  }

  static double _sinc(double x) {
    if (x == 0) {
      return 1;
    }
    x *= pi;
    return sin(x) / x;
  }
}

class TimeData {
  final double ts;
  final double mps;
  final double altitude;
  final double slope;
  final double? altitudeCorrected;
  final double? targetPace;

  static TimeData init(double x) {
    return TimeData(x, x, x, x, x, x);
  }

  TimeData(
    this.ts,
    this.mps,
    this.altitude,
    this.slope,
    this.altitudeCorrected,
    this.targetPace,
  );

  double bestAltitude() {
    return altitudeCorrected ?? altitude;
  }

  @override
  String toString() {
    return "@$ts: $mps - $targetPace";
  }
}

extension ListData on List<TimeData> {
  static List<TimeData> fromDoubles(
    List<double> ts,
    List<double> mps,
    List<double> altitude,
    List<double> slope,
    List<double>? altitudeCorrected,
    List<double>? targetPace,
  ) {
    assert(ts.length <= mps.length);
    assert(ts.length <= altitude.length);
    assert(ts.length <= slope.length);
    if (altitudeCorrected != null) {
      if (ts.length > altitudeCorrected.length) {
        altitudeCorrected = null;
      }
    }
    if (targetPace != null) {
      if (ts.length > targetPace.length) {
        targetPace = null;
      }
    }
    return ts.indexed
        .map(
          (t) => TimeData(
            t.$2,
            mps[t.$1],
            altitude[t.$1],
            slope[t.$1],
            altitudeCorrected?[t.$1],
            targetPace?[t.$1],
          ),
        )
        .toList();
  }

  static List<TimeData> fromSpeedPoints(List<SpeedPoint> points) {
    var time = 0.0;
    var lastDist = 0.0;
    return points
        .map((sp) {
          List<TimeData> ret = [
            TimeData(time, sp.speedMS, 0, 0, null, sp.speedMS),
          ];
          time += (sp.distanceM - lastDist) / sp.speedMS;
          lastDist = sp.distanceM;
          ret.add(TimeData(time, sp.speedMS, 0, 0, null, sp.speedMS));
          return ret;
        })
        .expand((list) => list)
        .toList();
  }

  List<XYData> speed() {
    return map((td) => XYData(td.ts, td.mps)).toList();
  }

  List<XYData> targetSpeed() {
    return map((td) => XYData(td.ts, td.targetPace ?? 0)).toList();
  }

  List<XYData> altitude() {
    return map((td) => XYData(td.ts, td.altitude)).toList();
  }

  List<XYData> altitudeCorrected() {
    return map(
      (td) => XYData(td.ts, td.altitudeCorrected ?? td.altitude),
    ).toList();
  }

  List<XYData> slope() {
    return map((td) => XYData(td.ts, td.slope)).toList();
  }


  List<SpeedPoint> speedPoints(){
    double distance = 0;
    double time = 0;
    return map((td) {
      distance += (td.ts - time) * td.mps;
      time = td.ts;
      return SpeedPoint(distanceM: distance, speedMS: td.mps);

    }).toList();
  }

}

extension PartialList<T> on List<T> {
  List<T> partial(int? maxLength) {
    if (maxLength == null || maxLength == 0 || maxLength >= length) {
      maxLength = length;
    }
    return List.generate(maxLength, (i) {
      return this[i * length ~/ maxLength!];
    });
  }
}

class XYData {
  XYData(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() {
    return "${x.toStringAsFixed(1)}: ${y.toStringAsFixed(1)}";
  }
}

extension ListXY on List<XYData> {
  /// Returns each element with its index (for debugging)
  String debug() {
    if (isEmpty) {
      return 'List is empty';
    }
    return map(
      (td) => "(${td.x.toStringAsFixed(1)}, ${td.y.toStringAsFixed(1)})",
    ).join(", ");
  }

  List<double> xs(){
    return map((xy) => xy.x).toList();
  }

  List<double> ys(){
    return map((xy) => xy.y).toList();
  }

  double maxY() {
    return reduce((a, b) => a.y > b.y ? a : b).y;
  }

  double minY() {
    return reduce((a, b) => a.y < b.y ? a : b).y;
  }

  double maxX() {
    return reduce((a, b) => a.x > b.x ? a : b).x;
  }

  double minX() {
    return reduce((a, b) => a.x < b.x ? a : b).x;
  }
}
