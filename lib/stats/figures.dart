import 'dart:math';

import 'package:flutter/material.dart';
import 'package:run_log/stats/filter_data.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'conversions.dart';

class Figures {
  List<Figure> figures = [Figure()];

  Figures();

  updateData(List<TimeData> runningData) {
    for (var figure in figures) {
      figure.updateData(runningData);
    }
  }

  addFigure() {
    figures.add(Figure());
  }

  addSpeed(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.speed, filterLength: filterLength),
    );
  }

  addAltitude(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.altitude, filterLength: filterLength),
    );
  }

  addSlope(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.slope, filterLength: filterLength),
    );
  }

  List<Widget> runStats() {
    final List<Widget> figs = [];
    for (var figure in figures) {
      figs.add(
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: SfCartesianChart(
            axes: figure.axes(),
            series: figure.series(),
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
            primaryYAxis: CategoryAxis(
              isVisible: false,
            ),
            legend: Legend(isVisible: true),
            tooltipBehavior: TooltipBehavior(enable: true),
          ),
        ),
      );
    }
    return figs;
  }
}

class Figure {
  List<LineStat> lines = [];

  Figure();

  updateData(List<TimeData> runningData) {
    for (var line in lines) {
      line.updateData(runningData);
    }
  }

  List<ChartAxis> axes() {
    return lines.map((line) => line.axe()).toList();
  }

  List<CartesianSeries> series() {
    return lines.map((line) => line.serie()).toList();
  }

  double maxValue() {
    return 10;
  }
}

enum LineType { speed, altitude, slope }

class LineStat {
  LineType type;
  late FilterData filter;

  LineStat({required this.type, required int filterLength}) {
    filter = FilterData(filterLength);
  }

  updateData(List<TimeData> runningData) {
    late List<XYData> xyd;
    switch (type) {
      case LineType.speed:
        xyd = runningData.speed();
      case LineType.altitude:
        xyd = runningData.altitude();
      case LineType.slope:
        xyd = runningData.slope();
    }
    filter.update(xyd);
  }

  CartesianSeries serie() {
    return LineSeries<XYData, String>(
      dataSource: filter.filteredData,
      yAxisName: _label(),
      animationDuration: 500,
      xValueMapper: (XYData entry, _) => timeHMS(entry.dt),
      yValueMapper: (XYData entry, _) => entry.y,
      name: _label(),
      dataLabelSettings: DataLabelSettings(isVisible: false),
    );
  }

  ChartAxis axe() {
    final (min, max) = minMax();
    return NumericAxis(
      name: _label(),
      minimum: min,
      maximum: max,
      isInversed: type == LineType.speed,
    );
  }

  (double, double) minMax() {
    if (filter.filteredData.isEmpty){
      return (0, 0);
    }
    switch (type) {
      case LineType.speed:
        return minMaxPace();
      case LineType.altitude:
      case LineType.slope:
        return (filter.min, filter.max);
    }
  }

  (double, double) minMaxPace() {
    // Pace is the inverse of speed, so it's normal that max is assigned to min,
    // and vice-versa.
    print("${filter.max} - ${filter.min}");
    var (minPace, maxPace) = (
      (speedMinKm(filter.max) * 6 - 1).toInt() / 6,
      (speedMinKm(filter.min) * 6 + 1).toInt() / 6,
    );
    var med = (maxPace + minPace) / 2;
    if (med + 0.5 > maxPace) {
      maxPace = med + 0.5;
    }
    if (med - 0.5 < minPace) {
      minPace = med - 0.5;
    }
    return (maxPace, minPace);
  }

  String _label() {
    switch (type) {
      case LineType.speed:
        return "Speed ${_filter()} [min/km]";
      case LineType.altitude:
        return "Altitude${_filter()} [m]";
      case LineType.slope:
        return "Slope${_filter()} [m/s]";
    }
  }

  String _filter() {
    final len = filter.lanczos.length;
    if (len == 1) {
      return "";
    }
    return " (${len * 5}s)";
  }
}

class FilterXY {
  List<XYData> filteredData = [];
  late List<double> lanczos;

  FilterSpeed(int filterN2) {
    lanczos = _lanczos(filterN2);
  }

  update(List<XYData> raw) {
    final data = _filterValues(raw.map((s) => s.y).toList());
    filteredData =
        raw
            .asMap()
            .entries
            .map((entry) => XYData(entry.value.dt, data[entry.key]))
            .toList();
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
    return src.asMap().entries.fold(
      0.0,
      (a, b) => a + b.value * filter[b.key] / sum,
    );
  }

  List<double> _filterValues(List<double> values) {
    return List.generate(values.length, (i) => _applyLanczos(values, i));
  }

  static List<double> _lanczos(int n2) {
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
