import 'dart:async';

import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';

import '../widgets/basic.dart';

class PaceWidget extends StatefulWidget {
  final StreamController<List<SFEntry>> updateEntries;

  const PaceWidget({super.key, required this.updateEntries});

  @override
  State<PaceWidget> createState() => _PaceWidgetState();
}

class _PaceWidgetState extends State<PaceWidget> {
  final _values = _PaceGlobal();

  @override
  Widget build(BuildContext context) {
    widget.updateEntries.add(
      _values.entries
          .map((e) => e.getEntries(_values))
          .expand((l) => l)
          .toList(),
    );
    return Expanded(
      flex: 0,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _values.entries.length,
        itemBuilder: (context, index) {
          final entry = _values.entries[index];
          return Card(
            child: InkWell(
              onTap:
                  () => setState(() {
                    entry.tap(context, _values);
                  }),
              child: entry.getWidget(() {
                setState(() {});
              }, _values),
            ),
          );
        },
      ),
    );
  }
}

class _PaceGlobal {
  List<_PaceEntryImp> entries = [];
  _Overall overall = _Overall();

  _PaceGlobal() {
    entries = [overall, _Warmup(), _Fill(), _Interval(), _Fill(), _Sprint()];
  }
}

abstract class _PaceEntryImp {
  Widget getWidget(VoidCallback setState, _PaceGlobal values);

  List<SFEntry> getEntries(_PaceGlobal values);

  tap(BuildContext context, _PaceGlobal values);
}

class _Warmup implements _PaceEntryImp {
  @override
  Widget getWidget(VoidCallback setState, _PaceGlobal values) {
    if (values.overall._active) {
      return Text("Warmup");
    } else {
      return Text("Cooldown");
    }
  }

  @override
  List<SFEntry> getEntries(_PaceGlobal values) {
    return [];
  }

  @override
  tap(BuildContext context, _PaceGlobal values) {}
}

class _Sprint implements _PaceEntryImp {
  @override
  Widget getWidget(VoidCallback setState, _PaceGlobal values) {
    return Text("Sprint");
  }

  @override
  List<SFEntry> getEntries(_PaceGlobal values) {
    return [];
  }

  @override
  tap(BuildContext context, _PaceGlobal values) {}
}

class _Fill implements _PaceEntryImp {
  @override
  Widget getWidget(VoidCallback setState, _PaceGlobal values) {
    return Text("Fill up run");
  }

  @override
  List<SFEntry> getEntries(_PaceGlobal values) {
    return [];
  }

  @override
  tap(BuildContext context, _PaceGlobal values) {}
}

class _Interval implements _PaceEntryImp {
  @override
  Widget getWidget(VoidCallback setState, _PaceGlobal values) {
    return Text("Interval training");
  }

  @override
  List<SFEntry> getEntries(_PaceGlobal values) {
    return [];
  }

  @override
  tap(BuildContext context, _PaceGlobal values) {}
}

class _Overall implements _PaceEntryImp {
  bool _active = false;
  double _feedbackPace = 6;

  @override
  List<SFEntry> getEntries(_PaceGlobal values) {
    return [];
  }

  @override
  Widget getWidget(VoidCallback setState, _PaceGlobal values) {
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
  tap(BuildContext context, _PaceGlobal values) {
    _active = !_active;
  }
}
