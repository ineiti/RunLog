import 'dart:math';

import 'package:flutter/material.dart';
import 'package:run_log/stats/filter_data.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'conversions.dart';

class Figures {
  List<Figure> figures = [Figure()];

  Figures();

  clean() {
    figures = [];
  }

  updateData(List<TimeData> runningData) {
    for (var figure in figures) {
      figure.updateData(runningData);
    }
  }

  addFigure() {
    figures.add(Figure());
  }

  addSlopeStats(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.slopeStats, filterLength: filterLength),
    );
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

  addAltitudeCorrected(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.altitudeCorrected, filterLength: filterLength),
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
            primaryYAxis: CategoryAxis(isVisible: false),
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
    final List<(LineType, (double, double))> axeMinMax =
        lines.map((l) => (l.type, l.minMax())).toList();
    axeMinMax.sort((a, b) => a.$1.toString().compareTo(b.$1.toString()));
    for (var pos = 0; pos + 1 < axeMinMax.length;) {
      final posMM = axeMinMax[pos];
      final nextMM = axeMinMax[pos + 1];
      if (posMM.$1 == nextMM.$1) {
        // As the speed is given as the pace in km/min, the minimum value is
        // the highest pace.
        final valMin = max(posMM.$2.$1, nextMM.$2.$1);
        final valMax = min(posMM.$2.$2, nextMM.$2.$2);
        axeMinMax[pos] = (posMM.$1, (valMin, valMax));
        axeMinMax.removeAt(pos + 1);
      } else {
        pos++;
      }
    }
    return axeMinMax.map((axe) => LineStat.axe(axe.$1, axe.$2)).toList();
  }

  List<CartesianSeries> series() {
    return lines.map((line) => line.serie()).expand((l) => l).toList();
  }

  double maxValue() {
    return 10;
  }
}

enum LineType { speed, altitude, altitudeCorrected, slope, slopeStats }

class LineStat {
  LineType type;
  late FilterData filter;
  late FilterData second;

  static ChartAxis axe(LineType type, (double, double) mm) {
    final (min, max) = mm;
    final inversed = type == LineType.speed || type == LineType.slope || type == LineType.slopeStats;
    final speedAxis = type == LineType.speed || type == LineType.slopeStats;
    return NumericAxis(
      name: "$type",
      minimum: min,
      maximum: max,
      opposedPosition: !speedAxis,
      axisLabelFormatter: (AxisLabelRenderDetails details) {
        if (speedAxis) {
          return ChartAxisLabel(labelYTime(details.text), details.textStyle);
        }
        return ChartAxisLabel(
          double.parse(details.text).toStringAsFixed(1),
          details.textStyle,
        );
      },
      isInversed: inversed,
    );
  }

  LineStat({required this.type, required int filterLength}) {
    filter = FilterData(filterLength);
    second = FilterData(filterLength);
  }

  updateData(List<TimeData> runningData) {
    late List<XYData> xyd;
    switch (type) {
      case LineType.speed:
        xyd = runningData.speed();
      case LineType.altitude:
        xyd = runningData.altitude();
      case LineType.altitudeCorrected:
        xyd = runningData.altitudeCorrected();
      case LineType.slope:
        xyd = runningData.slope();
      case LineType.slopeStats:
        filter.update(runningData.speed());
        second.update(runningData.slope());
        return;
    }
    filter.update(xyd);
    // print("Filter after update is: ${filter.filteredData.length}");
  }

  List<CartesianSeries> serie() {
    switch (type) {
      case LineType.speed:
      case LineType.altitudeCorrected:
      case LineType.altitude:
        return [_serieLines()];
      case LineType.slope:
        return [_serieSlope()];
      case LineType.slopeStats:
        return _serieSlopeStats();
    }
  }

  List<CartesianSeries> _serieSlopeStats() {
    final bins = 4;
    final slopes = List.from(second.filteredData).asMap().entries.toList();
    if (slopes.length < bins){
      return [_slopeStats((0, 0, []))];
    }
    slopes.sort((a, b) => a.value.y.compareTo(b.value.y));
    final List<(double, double, List<XYData>)> slopeStats = [
      (0, 0, filter.filteredData),
    ];
    for (int bin = 0; bin < bins; bin++) {
      final (from, to) = (
        slopes.length * bin ~/ bins,
        slopes.length * (bin + 1) ~/ bins - 1,
      );
      slopeStats.add((
        1,
        (slopes[from].value.y + slopes[to].value.y) / 2,
        slopes
            .sublist(from, to)
            .map((sl) => filter.filteredData[sl.key])
            .toList(),
      ));
    }
    // final List<(double, double, List<XYData>)> slopeStats = [
    //   (0, 0, [XYData(0, 0), XYData(5, 5), XYData(10, 10)]),
    //   (1, 2, [XYData(0, 10), XYData(10, 5), XYData(5, 0)])
    // ];
    return slopeStats.map((ss) => _slopeStats(ss)).toList();
  }

  CartesianSeries _slopeStats((double, double, List<XYData>) slopeStat) {
    // print(slopeStat);
    return ScatterSeries<XYData, String>(
      dataSource: slopeStat.$3,
      yAxisName: "$type",
      opacity: slopeStat.$1,
      isVisibleInLegend: slopeStat.$1 > 0.5,
      animationDuration: 500,
      xValueMapper: (XYData entry, _) => timeHMS(entry.dt),
      yValueMapper: (XYData entry, _) => toPaceMinKm(entry.y),
      name: slopeStat.$2.toStringAsFixed(1),
      dataLabelSettings: DataLabelSettings(isVisible: false),
    );
  }

  CartesianSeries _serieLines() {
    // print("Filtered data is: ${filter.filteredData.length}");
    return LineSeries<XYData, String>(
      dataSource: filter.filteredData,
      yAxisName: "$type",
      animationDuration: 500,
      xValueMapper: (XYData entry, _) => timeHMS(entry.dt),
      yValueMapper:
          (XYData entry, _) =>
              type == LineType.speed ? toPaceMinKm(entry.y) : entry.y,
      name: _label(),
      dataLabelSettings: DataLabelSettings(isVisible: false),
    );
  }

  CartesianSeries _serieSlope() {
    return ColumnSeries<XYData, String>(
      dataSource: filter.filteredData,
      xValueMapper: (XYData entry, _) => timeHMS(entry.dt),
      yValueMapper: (XYData entry, _) => entry.y,
      yAxisName: "$type",
      name: _label(),
      pointColorMapper:
          (XYData entry, _) =>
              entry.y >= 0 ? Color(0xFFFFBBBB) : Color(0xFF99FF99),
    );
  }

  (double, double) minMax() {
    if (filter.filteredData.isEmpty) {
      return (0, 0);
    }
    switch (type) {
      case LineType.slopeStats:
      // return (0, 10);
      case LineType.speed:
        return minMaxPace();
      case LineType.altitudeCorrected:
      case LineType.altitude:
        return (filter.min.floorToDouble(), filter.max.ceilToDouble());
      case LineType.slope:
        var (min, max) = (filter.min.floor().abs(), filter.max.ceil().abs());
        var abs = min > max ? min : max;
        return (-abs.toDouble(), abs.toDouble());
    }
  }

  (double, double) minMaxPace() {
    // Pace is the inverse of speed, so it's normal that max is assigned to min,
    // and vice-versa.
    var (minPace, maxPace) = (
      (toPaceMinKm(filter.max) * 6).floor() / 6,
      (toPaceMinKm(filter.min) * 6).ceil() / 6,
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
        return "Speed ${_filter()}";
      case LineType.altitudeCorrected:
        return "Alt Corr ${_filter()}";
      case LineType.altitude:
        return "Alt${_filter()}";
      case LineType.slope:
        // print("Slope: ${filter.filteredData}");
        return "Slope${_filter()}";
      case LineType.slopeStats:
        return "SlopeStat";
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
