import 'dart:async';

import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';
import 'package:run_log/stats/conversions.dart';

import '../widgets/basic.dart';

class PaceWidget extends StatefulWidget {
  final StreamController<SFEntry> updateEntries;

  const PaceWidget({super.key, required this.updateEntries});

  @override
  State<PaceWidget> createState() => _PaceWidgetState();
}

class _PaceWidgetState extends State<PaceWidget> {
  final _values = _Container();

  @override
  Widget build(BuildContext context) {
    widget.updateEntries.add(
      SFEntry.fromPoints(
        _values.entries.map((e) => e.getPoints()).expand((l) => l).toList(),
      ),
    );
    return Column(
      children: [
        blueButton("Clear", () {
          setState(() {
            _values.entries = [_PaceAdder(_values, 0)];
          });
        }),
        Flexible(
          flex: 1,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _values.entries.length,
            itemBuilder: (context, index) {
              final entry = _values.entries[index];
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
  }
}

class _Container {
  List<_PaceEntryImp> entries = [];

  _Container() {
    entries = [_PaceAdder(this, 0)];
  }
}

abstract class _PaceEntryImp {
  _Entries get type;

  Widget getWidget(VoidCallback setState);

  List<SpeedPoint> getPoints();
}

enum _Entries { adder, pace, paceLength, intervals }

class _PaceAdder implements _PaceEntryImp {
  final _Container values;
  int position;

  _PaceAdder(this.values, this.position);

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

  _insertEntry(_Entries entry) {
    _PaceEntryImp? imp;
    int newPos = position;
    switch (entry) {
      case _Entries.adder:
        return;
      case _Entries.pace:
        imp = _Pace();
        if (values.entries.length == 1) {
          newPos++;
        }
      case _Entries.paceLength:
        imp = _PaceLength();
        if (values.entries.length == 1) {
          values.entries.add(_PaceAdder(values, position + 2));
          newPos++;
        }
      case _Entries.intervals:
        imp = _PaceIntervals(values);
        if (values.entries.length == 1) {
          values.entries.add(_PaceAdder(values, position + 2));
          newPos++;
        }
    }
    values.entries.insert(newPos, imp);
  }

  List<_Entries> _validEntries() {
    print("Position is $position");
    if (values.entries.any((e) => e.type == _Entries.pace) ||
        (position == 0 && values.entries.length > 1)) {
      return _Entries.values.where((v) => v != _Entries.pace).toList();
    }
    return _Entries.values;
  }
}

class _Pace implements _PaceEntryImp {
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

class _PaceLength implements _PaceEntryImp {
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
    return [];
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
      final paceSM = _pace * 60 / 1000;
      switch (_dudi) {
        case _PLDuDi.duration:
          _distance.setM((_duration.getSec() / paceSM).toInt());
        case _PLDuDi.distance:
          _duration.setSec((paceSM * _distance.getM()).toInt());
      }
      setState();
    };
  }
}

class _PaceIntervals implements _PaceEntryImp {
  _Container values;
  int _repetitions = 4;
  final _PaceLength _first = _PaceLength();
  final _PaceLength _second = _PaceLength();

  _PaceIntervals(this.values);

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
    return [];
  }
}
