import 'dart:math';

class FilterData {
  List<XYData> filteredData = [];
  late List<double> lanczos;
  int filteredSize = 0;
  double min = double.infinity;
  double max = -double.infinity;

  static FilterData subSampled(int filterN2, int maxSize) {
    var fd = FilterData(filterN2);
    fd.filteredSize = maxSize;
    return fd;
  }

  FilterData(int filterN2) {
    lanczos = _lanczos(filterN2);
  }

  update(List<XYData> raw) {
    min = double.infinity;
    max = -double.infinity;
    final values = raw.map((s) => s.y).toList();
    int length = values.length;
    if (filteredSize > 0 && filteredSize < length) {
      length = filteredSize;
    }
    filteredData = List.generate(length, (i) {
      final pos = i * values.length ~/ length;
      return XYData(raw[pos].dt, _applyLanczos(values, pos));
    });
  }

  // Applies the lanczos filter to 'values' and keeps the peak at 'pos'.
  // If the lanczos filter doesn't fit, it will be cut and thus not return
  // a nice sampling window.
  double _applyLanczos(List<double> values, int pos) {
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
  final double? altitudeCorrected;
  final double slope;

  TimeData(
    this.ts,
    this.mps,
    this.altitude,
    this.altitudeCorrected,
    this.slope,
  );
}

extension ListData on List<TimeData> {
  List<XYData> speed() {
    return map((td) => XYData(td.ts, td.mps)).toList();
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
}

class XYData {
  XYData(this.dt, this.y);

  final double dt;
  final double y;

  @override
  String toString() {
    return "${dt.toStringAsFixed(1)}: ${y.toStringAsFixed(1)}";
  }
}

extension ListXY on List<XYData> {
  /// Prints each element with its index (for debugging)
  String debug() {
    if (isEmpty) {
      return 'List is empty';
    }
    return map(
      (td) => "(${td.dt.toStringAsFixed(1)}, ${td.y.toStringAsFixed(1)})",
    ).join(", ");
  }

  double maxSpeed() {
    return reduce((a, b) => a.y > b.y ? a : b).y;
  }

  double minSpeed() {
    return reduce((a, b) => a.y < b.y ? a : b).y;
  }
}
