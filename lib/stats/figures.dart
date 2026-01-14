import 'dart:math';

import 'package:flutter/material.dart';
import 'package:run_log/stats/filter_data.dart';
import 'package:scidart/numdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'conversions.dart';

const int axisIntervals = 4;
const int minuteIntervals = 6;

class Figures {
  List<Figure> figures = [Figure()];

  Figures();

  void clean() {
    figures = [];
  }

  void updateRunningData(List<TimeData> runningData) {
    for (var figure in figures) {
      figure.updateRunningData(runningData);
    }
  }

  void addFigure() {
    figures.add(Figure());
  }

  void addSlopeStats(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.slopeStats, filterLength: filterLength),
    );
  }

  void addSpeed(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.speed, filterLength: filterLength),
    );
  }

  void addTargetPace(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.targetPace, filterLength: filterLength),
    );
  }

  void addAltitude(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.altitude, filterLength: filterLength),
    );
  }

  void addAltitudeCorrected(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.altitudeCorrected, filterLength: filterLength),
    );
  }

  void addSlope(int filterLength) {
    figures.last.lines.add(
      LineStat(type: LineType.slope, filterLength: filterLength),
    );
  }

  Widget runStats() {
    return Flexible(
      child: ListView.builder(
        itemBuilder: (context, index) {
          return _buildFigure(index);
        },
      ),
    );
  }

  Widget? _buildFigure(int index) {
    if (index >= figures.length) {
      return null;
    }
    return figures[index].chart();
  }
}

class Figure {
  List<LineStat> lines = [];

  Figure();

  void updateRunningData(List<TimeData> runningData) {
    for (var line in lines) {
      line.updateData(runningData);
    }
  }

  SfCartesianChart chart() {
    if (lines.length == 1 && lines.first.type == LineType.slopeSpeed) {
      return chartXY(lines.first);
    }
    return chartYTime();
  }

  SfCartesianChart chartYTime() {
    return SfCartesianChart(
      axes: _axes(),
      series: _series(),
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
    );
  }

  SfCartesianChart chartXY(LineStat line) {
    final mm = line.minMax();
    final mmx =
        max(
          line.filter.tdMin.slope.abs(),
          line.filter.tdMax.slope.abs(),
        ).ceilToDouble();
    return SfCartesianChart(
      axes: [
        NumericAxis(
          name: line.type.axisRef,
          minimum: toPaceMinKm(mm.$1).ceilToDouble(),
          maximum: toPaceMinKm(mm.$2).floorToDouble(),
          desiredIntervals: axisIntervals,
        ),
        NumericAxis(
          name: "${line.type.axisRef}x",
          minimum: -mmx,
          maximum: mmx,
          desiredIntervals: axisIntervals,
        ),
      ],
      series: line.serie(),
      primaryXAxis: CategoryAxis(
        labelIntersectAction: AxisLabelIntersectAction.multipleRows,
      ),
      primaryYAxis: CategoryAxis(isVisible: false),
    );
  }

  List<ChartAxis> _axes() {
    final List<(LineType, (double, double))> axeMinMax =
        lines.map((l) => (l.type, l.minMax())).toList();
    axeMinMax.sort((a, b) => a.$1.toString().compareTo(b.$1.toString()));
    for (var pos = 0; pos + 1 < axeMinMax.length;) {
      final posMM = axeMinMax[pos];
      final nextMM = axeMinMax[pos + 1];
      if (posMM.$1.speedAxis && nextMM.$1.speedAxis) {
        final (valMin, valMax) = createIntervals(
          6,
          axisIntervals,
          min(posMM.$2.$1, nextMM.$2.$1),
          max(posMM.$2.$2, nextMM.$2.$2),
        );
        axeMinMax[pos] = (posMM.$1, (valMin, valMax));
        axeMinMax.removeAt(pos + 1);
      } else {
        pos++;
      }
    }
    return axeMinMax.map((axe) => _chartAxis(axe.$1, axe.$2)).toList();
  }

  List<CartesianSeries> _series() {
    return lines.map((line) => line.serie()).expand((l) => l).toList();
  }

  ChartAxis _chartAxis(LineType type, (double, double) mm) {
    final (min, max) = mm;
    return NumericAxis(
      name: type.axisRef,
      minimum: min,
      maximum: max,
      opposedPosition: !type.speedAxis,
      desiredIntervals: axisIntervals,
      axisLabelFormatter: (AxisLabelRenderDetails details) {
        if (type.speedAxis) {
          return ChartAxisLabel(labelYTime(details.text), details.textStyle);
        }
        return ChartAxisLabel(
          double.parse(details.text).toStringAsFixed(1),
          details.textStyle,
        );
      },
      isInversed: type.inversed,
    );
  }
}

enum LineType {
  speed,
  altitude,
  altitudeCorrected,
  slope,
  slopeStats,
  targetPace,
  slopeSpeed;

  bool get speedType => this == LineType.speed || this == LineType.targetPace;

  bool get speedAxis => speedType || this == LineType.slopeStats;

  bool get inversed => speedAxis || this == LineType.slope;

  String get axisRef => speedAxis ? "speed" : name;
}

class LineStat {
  LineType type;
  late FilterData filter;
  static const maxPoints = 500;

  LineStat({required this.type, required int filterLength}) {
    filter = FilterData.subSampled(filterLength, maxPoints);
  }

  void updateData(List<TimeData> runningData) {
    filter.replace(runningData);
    // print("Filter after update is: ${filter.filteredData.length}");
  }

  List<CartesianSeries> serie() {
    switch (type) {
      case LineType.speed:
      case LineType.targetPace:
      case LineType.altitudeCorrected:
      case LineType.altitude:
        return [_serieLines()];
      case LineType.slope:
        return [_seriePoints()];
      case LineType.slopeStats:
        return _serieSlopeStats();
      case LineType.slopeSpeed:
        return [_serieSlopeSpeed()];
    }
  }

  List<XYData> _xyData() {
    switch (type) {
      case LineType.speed:
        return filter.filteredData.speed();
      case LineType.targetPace:
        return filter.filteredData.targetSpeed();
      case LineType.altitudeCorrected:
        return filter.filteredData.altitudeCorrected();
      case LineType.altitude:
        return filter.filteredData.altitude();
      case LineType.slope:
        return filter.filteredData.slope();
      case LineType.slopeStats:
        return filter.filteredData.slope();
      case LineType.slopeSpeed:
        final xs = filter.filteredData.slope().partial(100);
        final ys = filter.filteredData.speed().partial(100);
        final regression = PolyFit(Array(xs.ys()), Array(ys.ys()), 3);
        final points = 50;
        final xsMin = xs.minY();
        final xsMul = (xs.maxY() - xsMin) / points;
        return List.generate(points, (i) {
          final x = xsMin + xsMul * i;
          return XYData(x, regression.predict(x));
        });
    }
  }

  List<CartesianSeries> _serieSlopeStats() {
    final bins = 4;
    final slopeXY = filter.filteredData.slope();
    final slopes = slopeXY.asMap().entries.toList();
    if (slopes.length < bins) {
      return [_slopeStats((0, 0, []))];
    }
    slopes.sort((a, b) => a.value.y.compareTo(b.value.y));
    final List<(double, double, List<XYData>)> slopeStats = [(0, 0, slopeXY)];
    final speeds = filter.filteredData.speed();
    for (int bin = 0; bin < bins; bin++) {
      final (from, to) = (
        slopes.length * bin ~/ bins,
        slopes.length * (bin + 1) ~/ bins - 1,
      );
      slopeStats.add((
        1,
        (slopes[from].value.y + slopes[to].value.y) / 2,
        slopes.sublist(from, to).map((sl) => speeds[sl.key]).toList(),
      ));
    }
    // final List<(double, double, List<XYData>)> slopeStats = [
    //   (0, 0, [XYData(0, 0), XYData(5, 5), XYData(10, 10)]),
    //   (1, 2, [XYData(0, 10), XYData(10, 5), XYData(5, 0)])
    // ];
    return slopeStats.map((ss) => _slopeStats(ss)).toList();
  }

  CartesianSeries _slopeStats((double, double, List<XYData>) slopeStat) {
    return ScatterSeries<XYData, String>(
      dataSource: slopeStat.$3,
      yAxisName: type.axisRef,
      opacity: slopeStat.$1,
      isVisibleInLegend: slopeStat.$1 > 0.5,
      animationDuration: 500,
      xValueMapper: (XYData entry, _) => shortHMS(entry.x),
      yValueMapper: (XYData entry, _) => toPaceMinKm(entry.y),
      name: slopeStat.$2.toStringAsFixed(1),
      dataLabelSettings: DataLabelSettings(isVisible: false),
    );
  }

  CartesianSeries _serieSlopeSpeed() {
    // print("Filtered data is: ${filter.filteredData.length}");
    return ScatterSeries<XYData, double>(
      dataSource: _xyData(),
      xAxisName: "${type.axisRef}x",
      yAxisName: type.axisRef,
      animationDuration: 500,
      xValueMapper: (XYData entry, _) => entry.x,
      yValueMapper: (XYData entry, _) => toPaceMinKm(entry.y),
      name: _label(),
      dataLabelSettings: DataLabelSettings(isVisible: false),
    );
  }

  CartesianSeries _serieLines() {
    // print("Filtered data is: ${filter.filteredData.length}");
    return LineSeries<XYData, String>(
      dataSource: _xyData(),
      yAxisName: type.axisRef,
      animationDuration: 500,
      xValueMapper: (XYData entry, _) => shortHMS(entry.x),
      yValueMapper:
          (XYData entry, _) => type.speedType ? toPaceMinKm(entry.y) : entry.y,
      name: _label(),
      dataLabelSettings: DataLabelSettings(isVisible: false),
    );
  }

  CartesianSeries _seriePoints() {
    return ColumnSeries<XYData, String>(
      dataSource: _xyData(),
      xValueMapper: (XYData entry, _) => shortHMS(entry.x),
      yValueMapper: (XYData entry, _) => entry.y,
      yAxisName: type.axisRef,
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
      case LineType.targetPace:
        return createIntervals(
          minuteIntervals,
          axisIntervals,
          (toPaceMinKm(filter.tdMax.targetPace ?? 0) * minuteIntervals)
                  .floor() /
              minuteIntervals,
          (toPaceMinKm(filter.tdMin.targetPace ?? 0) * minuteIntervals).ceil() /
              minuteIntervals,
        );
      case LineType.slopeStats:
      case LineType.speed:
        // The filter has the speed meter/sec, but the pace is 1/speed,
        // so the minimum pace is the maximum speed, and vice-versa.
        return createIntervals(
          minuteIntervals,
          axisIntervals,
          (toPaceMinKm(filter.tdMax.mps) * minuteIntervals).floor() /
              minuteIntervals,
          (toPaceMinKm(filter.tdMin.mps) * minuteIntervals).ceil() /
              minuteIntervals,
        );
      case LineType.altitudeCorrected:
        return (
          filter.tdMin.bestAltitude().floorToDouble(),
          filter.tdMax.bestAltitude().ceilToDouble(),
        );
      case LineType.altitude:
        return (
          filter.tdMin.altitude.floorToDouble(),
          filter.tdMax.altitude.ceilToDouble(),
        );
      case LineType.slope:
        var (min, max) = (
          filter.tdMin.slope.floor().abs(),
          filter.tdMax.slope.ceil().abs(),
        );
        var abs = (min > max ? min : max).ceil();
        return createIntervals(
          1,
          axisIntervals,
          -abs.toDouble(),
          abs.toDouble(),
        );
      case LineType.slopeSpeed:
        final xy = _xyData();
        return (xy.minY(), xy.maxY());
    }
  }

  String _label() {
    switch (type) {
      case LineType.speed:
        return "Speed ${_filter()}";
      case LineType.targetPace:
        return "Pace ${_filter()}";
      case LineType.altitudeCorrected:
        return "Alt Corr ${_filter()}";
      case LineType.altitude:
        return "Alt${_filter()}";
      case LineType.slope:
        return "Slope${_filter()}";
      case LineType.slopeStats:
        return "SlopeStat";
      case LineType.slopeSpeed:
        return "SlopeSpeed";
    }
  }

  String _filter() {
    final len = filter.length();
    if (len <= 1) {
      return "";
    }
    return " (${len}s)";
  }
}

(double, double) createIntervals(
  int mult,
  int intervals,
  double min,
  double max,
) {
  min = (min * mult).roundToDouble();
  max = (max * mult).roundToDouble();
  final off = axisIntervals - (max - min) % axisIntervals;
  final incMax = (off / 2).ceil();
  final decMin = off - incMax;
  max += incMax;
  min -= decMin;
  return (min / mult, max / mult);
}
