import 'dart:async';

import 'package:flutter/material.dart';
import '../../feedback/feedback.dart';
import '../../feedback/tones.dart';
import '../../stats/conversions.dart';

import '../../stats/figures.dart';
import '../../stats/filter_data.dart';
import '../basic.dart';

class PaceWidget extends StatefulWidget {
  static StreamController<List<PaceEntryImp>> initEntries = StreamController();
  final StreamController<FeedbackContainer> updateEntries;

  const PaceWidget({super.key, required this.updateEntries});

  @override
  State<PaceWidget> createState() => _PaceWidgetState();
}

class _PaceWidgetState extends State<PaceWidget> {
  final List<PaceEntryImp> _entries = [];

  @override
  void initState() {
    super.initState();
    _entries.add(_PaceAdder(_entries, _AdderPos.beginning));
  }

  @override
  Widget build(BuildContext context) {
    var pointsSum = _points.clone();
    pointsSum.calcSum();
    widget.updateEntries.add(FeedbackContainer.fromPace(pointsSum));
    return StreamBuilder(
      stream: PaceWidget.initEntries.stream,
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          if (snapshot.data!.isNotEmpty) {
            _entries.clear();
            _entries.addAll(snapshot.data!);
            PaceWidget.initEntries.add([]);
          }
        }
        return Column(
          children: [
            blueButton("Clear", () {
              PaceWidget.initEntries.add([
                _PaceAdder(_entries, _AdderPos.beginning),
              ]);
            }),
            _totalFeedback(),
            Flexible(
              flex: 1,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Card(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: entry.getWidget(() {
                        setState(() {});
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  SFEntry get _points => SFEntry.fromPoints(
    _entries.map((e) => e.getPoints()).expand((l) => l).toList(),
  );

  Widget _totalFeedback() {
    double duration = 0;
    double distance = 0;
    for (final p in _points.targetSpeeds) {
      if (p.speedMS > 0 && p.distanceM > 0) {
        distance += p.distanceM;
        duration += (p.distanceM / p.speedMS).round();
      }
    }
    return Visibility(
      visible: duration > 0 && distance > 0,
      child: Row(
        children: [
          Text("Duration: ${timeHMS(duration)}"),
          Spacer(),
          Text("Distance: ${distanceStr(distance)}"),
        ],
      ),
    );
  }
}

abstract class PaceEntryImp {
  _Entries get type;

  Widget getWidget(VoidCallback setState);

  List<SpeedPoint> getPoints();
}

class ReRun implements PaceEntryImp {
  double _paceMinKm = 6;
  final List<SpeedPoint> _runOrig;
  late List<SpeedPoint> _run;
  late double _dist;
  late double _duration;
  late double _pace;

  ReRun(this._runOrig) {
    final sf = SFEntry.fromPoints(_runOrig);
    _dist = sf.getDistance();
    _duration = sf.getDurationS(_dist);
    _pace = toPaceMinKm(_dist / _duration);
    _paceMinKm = _pace;
    _updateRun();
  }

  @override
  _Entries get type => _Entries.reRun;

  @override
  Widget getWidget(VoidCallback setState) {
    final figure = Figure();
    figure.lines.add(LineStat(type: LineType.targetPace, filterLength: 1));
    figure.updateRunningData(ListData.fromSpeedPoints(_run));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Distance: ${distanceStr(_dist)} - Orig. pace: ${minSec(_pace)}"),
        paceSlider(
          (value) {
            _paceMinKm = value;
            _updateRun();
            setState();
          },
          _paceMinKm,
          "Pace",
          4,
          8,
        ),
        figure.chart(),
      ],
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    var lastDistance = 0.0;
    return _runOrig.map((sp) {
      final ret = SpeedPoint(
        distanceM: sp.distanceM - lastDistance,
        speedMS: sp.speedMS * _pace / _paceMinKm,
      );
      lastDistance = sp.distanceM;
      return ret;
    }).toList();
  }

  void _updateRun() {
    _run =
        _runOrig
            .map(
              (sp) => SpeedPoint(
                distanceM: sp.distanceM,
                speedMS: sp.speedMS * _pace / _paceMinKm,
              ),
            )
            .toList();
  }
}

enum _Entries { adder, pace, paceLength, intervals, reRun }

enum _AdderPos { beginning, end }

class _PaceAdder implements PaceEntryImp {
  final List<PaceEntryImp> _entries;
  final _AdderPos position;

  _PaceAdder(this._entries, this.position);

  @override
  Widget getWidget(VoidCallback setState) {
    return DropdownButton(
      value: _Entries.adder,
      icon: const Icon(Icons.arrow_downward),
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(height: 2, color: Colors.deepPurpleAccent),
      onChanged: (_Entries? value) {
        if (value != null) {
          _insertEntry(value);
          setState();
        }
      },
      items:
          _validEntries()
              .map(
                (value) => DropdownMenuItem<_Entries>(
                  value: value,
                  child: Text(value.toString()),
                ),
              )
              .toList(),
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    return [];
  }

  @override
  _Entries get type => _Entries.adder;

  void _insertEntry(_Entries entry) {
    PaceEntryImp? imp;
    var insert = position == _AdderPos.beginning ? 1 : _entries.length - 1;
    switch (entry) {
      case _Entries.adder:
        return;
      case _Entries.reRun:
        return;
      case _Entries.pace:
        imp = _Pace();
      case _Entries.paceLength:
        imp = _PaceLength();
      case _Entries.intervals:
        imp = _PaceIntervals();
    }
    _entries.insert(insert, imp);
    if (_entries.length == 2) {
      _entries.add(_PaceAdder(_entries, _AdderPos.end));
    }
    if (imp.type == _Entries.pace) {
      _entries.removeLast();
    }
  }

  List<_Entries> _validEntries() {
    if (_entries.any((e) => e.type == _Entries.pace) ||
        (position == _AdderPos.beginning && _entries.length > 1)) {
      return _Entries.values.where((v) => v != _Entries.pace).toList();
    }
    return _Entries.values;
  }
}

class _Pace implements PaceEntryImp {
  double _paceMinKm = 6;

  _Pace();

  @override
  _Entries get type => _Entries.pace;

  @override
  Widget getWidget(VoidCallback setState) {
    return paceSlider(
      (value) {
        _paceMinKm = value;
        setState();
      },
      _paceMinKm,
      "Pace",
      4,
      8,
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    return [SpeedPoint.speed(toSpeedMS(_paceMinKm))];
  }
}

enum _PLDuDi { duration, distance }

class _PaceLength implements PaceEntryImp {
  double _pace = 6;
  final TimeHMS _duration = TimeHMS("Duration", 0, 12, 0);
  final LengthKmM _distance = LengthKmM("Distance", 2, 0);
  _PLDuDi _dudi = _PLDuDi.duration;

  _PaceLength();

  @override
  _Entries get type => _Entries.paceLength;

  @override
  Widget getWidget(VoidCallback setState) {
    return Column(
      children: [
        paceSlider(
          (value) {
            _pace = value;
            _updateDuDi(setState, null)();
          },
          _pace,
          "Pace Duration",
          4,
          8,
        ),
        _duDiWidget(
          setState,
          _PLDuDi.duration,
          _duration.dropdownWidget(_updateDuDi(setState, _PLDuDi.duration)),
        ),
        _duDiWidget(
          setState,
          _PLDuDi.distance,
          _distance.dropdownWidget(_updateDuDi(setState, _PLDuDi.distance)),
        ),
      ],
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    switch (_dudi) {
      case _PLDuDi.duration:
        return [SpeedPoint.fromMinKm(_duration.getSec() / _paceSM, _pace)];
      case _PLDuDi.distance:
        return [SpeedPoint.fromMinKm(_distance.getM().toDouble(), _pace)];
    }
  }

  Widget _duDiWidget(VoidCallback setState, _PLDuDi dudi, Widget w) {
    final color = _dudi == dudi ? Colors.tealAccent : Colors.transparent;
    return InkWell(
      onTap: () {
        _dudi = dudi;
        setState();
      },
      child: Container(color: color, width: double.infinity, child: w),
    );
  }

  VoidCallback _updateDuDi(VoidCallback setState, _PLDuDi? source) {
    return () {
      if (source != null) {
        _dudi = source;
      }
      switch (_dudi) {
        case _PLDuDi.duration:
          _distance.setM((_duration.getSec() / _paceSM).toInt());
        case _PLDuDi.distance:
          _duration.setSec((_paceSM * _distance.getM()).toInt());
      }
      setState();
    };
  }

  double get _paceSM => _pace * 60 / 1000;
}

class _PaceIntervals implements PaceEntryImp {
  int _repetitions = 4;
  final _PaceLength _first = _PaceLength();
  final _PaceLength _second = _PaceLength();

  _PaceIntervals();

  @override
  _Entries get type => _Entries.intervals;

  @override
  Widget getWidget(VoidCallback setState) {
    return Column(
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      // crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Intervals: "),
            dropdown(List.generate(20, (i) => i), _repetitions, (v) {
              _repetitions = v;
              setState();
            }, (v) => "$v x"),
          ],
        ),
        _first.getWidget(setState), _second.getWidget(setState),
        // Text("456"),
      ],
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    return List.generate(
      _repetitions,
      (i) => [_first.getPoints()[0], _second.getPoints()[0]],
    ).expand((l) => l).toList();
  }
}
