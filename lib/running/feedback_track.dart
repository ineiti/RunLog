import 'dart:async';

import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';

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
                  child: InkWell(
                    onTap:
                        () => setState(() {
                          entry.tap(context);
                        }),
                    child: entry.getWidget(() {
                      setState(() {});
                    }),
                  ),
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
  _Overall overall = _Overall();

  _Container() {
    entries = [_PaceAdder(this, 0)];
  }
}

abstract class _PaceEntryImp {
  Widget getWidget(VoidCallback setState);

  List<SpeedPoint> getPoints();

  tap(BuildContext context);
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
  tap(BuildContext context) {}

  _insertEntry(_Entries entry) {
    _PaceEntryImp? imp;
    switch (entry) {
      case _Entries.adder:
        return;
      case _Entries.pace:
        imp = _Pace();
        if (values.entries.length == 1) {
          position++;
        }
      case _Entries.paceLength:
        imp = _PaceLength();
        if (values.entries.length == 1) {
          values.entries.add(_PaceAdder(values, position + 2));
          position++;
        }
      case _Entries.intervals:
        imp = _PaceIntervals(values);
    }
    values.entries.insert(position, imp);
  }

  // TODO: Correctly restrict possible values.
  List<_Entries> _validEntries() {
    return _Entries.values;
  }
}

class _Pace implements _PaceEntryImp {
  double _pace = 6;

  _Pace();

  @override
  Widget getWidget(VoidCallback setState) {
    return paceSlider(
      (value) {
        _pace = value;
        setState();
      },
      _pace,
      "Pace",
      4,
      8,
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    return [];
  }

  @override
  tap(BuildContext context) {}
}

class _PaceLength implements _PaceEntryImp {
  double _pace = 6;
  final TimeHMS _duration = TimeHMS("Duration", 0, 10, 0);

  _PaceLength();

  @override
  Widget getWidget(VoidCallback setState) {
    return Column(
      children: [
        paceSlider(
          (value) {
            _pace = value;
            setState();
          },
          _pace,
          "Pace",
          4,
          8,
        ),
        _duration.dropdownWidget(setState),
      ],
    );
  }

  @override
  List<SpeedPoint> getPoints() {
    return [];
  }

  @override
  tap(BuildContext context) {}
}

class _PaceIntervals implements _PaceEntryImp {
  _Container values;

  _PaceIntervals(this.values);

  @override
  Widget getWidget(VoidCallback setState) {
    if (values.overall._active) {
      return Text("Warmup");
    } else {
      return Text("Cooldown");
    }
  }

  @override
  List<SpeedPoint> getPoints() {
    return [];
  }

  @override
  tap(BuildContext context) {}
}

class _Overall implements _PaceEntryImp {
  bool _active = false;
  double _feedbackPace = 6;

  @override
  List<SpeedPoint> getPoints() {
    return [];
  }

  @override
  Widget getWidget(VoidCallback setState) {
    if (!_active) {
      return Text("Click to set overall pace");
    } else {
      // if (_feedbackPace < config.config.minFeedbackPace) {
      //   _feedbackPace = config.config.minFeedbackPace;
      // } else if (_feedbackPace > config.config.maxFeedbackPace) {
      //   _feedbackPace = config.config.maxFeedbackPace;
      // }
      return paceSlider(
        (newValue) {
          _feedbackPace = newValue;
          setState();
        },
        _feedbackPace,
        "Overall Pace",
        4,
        6,
      );
    }
  }

  @override
  tap(BuildContext context) {
    _active = !_active;
  }
}
