import 'dart:math';

class FilterData {
  List<XYData> filteredData = [];
  late List<double> lanczos;
  double min = double.infinity;
  double max = -double.infinity;

  FilterData(int filterN2) {
    lanczos = _lanczos(filterN2);
  }

  update(List<XYData> raw) {
    // TODO: only update the necessary elements, depending on the size of lanczos.
    final data = _filterValues(raw.map((s) => s.y).toList());
    filteredData =
        raw
            .asMap()
            .entries
            .map((entry) => XYData(entry.value.dt, data[entry.key]))
            .toList();
  }

  List<double> _filterValues(List<double> values) {
    min = double.infinity;
    max = -double.infinity;
    return List.generate(values.length, (i) => _applyLanczos(values, i));
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
  final double slope;

  TimeData(this.ts, this.mps, this.altitude, this.slope);
}

extension ListData on List<TimeData> {
  List<XYData> speed() {
    return map((td) => XYData(td.ts, td.mps)).toList();
  }

  List<XYData> altitude() {
    return map((td) => XYData(td.ts, td.altitude)).toList();
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
