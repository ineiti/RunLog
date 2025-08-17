import 'dart:async';

import 'package:flutter/material.dart';
import 'package:run_log/running/feedback_track.dart';
import 'package:run_log/running/tones.dart';

import '../configuration.dart';

class ToneFeedback {
  int _soundIntervalS = 5;
  PaceWidget _pace;
  final StreamController<SFEntry> _paceUpdates;
  int _nextSoundS = 0;
  int _maxFeedbackSoundWait = 4;
  final Tones _feedback;

  static Future<ToneFeedback> init() async {
    final _paceUpdates = StreamController<SFEntry>();
    return ToneFeedback(
      await Tones.init(),
      _paceUpdates,
      PaceWidget(updateEntries: _paceUpdates),
    );
  }

  ToneFeedback(this._feedback, this._paceUpdates, this._pace){
    _paceUpdates.stream.listen((update) => _feedback.setEntry(update));
  }

  startRunning(int maxFeedbackSoundWait) async {
    _nextSoundS = _soundIntervalS;
    _maxFeedbackSoundWait = maxFeedbackSoundWait;
  }

  updateRunning(double durationS, double distanceM) async {
    if (_feedback.hasEntry()) {
      // print("${runStats!.duration()} / $lastSoundS");
      if (durationS >= _nextSoundS) {
        await _feedback.playSound(_maxFeedbackSoundWait, distanceM, durationS);
        while (_nextSoundS <= durationS) {
          _nextSoundS += _soundIntervalS;
        }
      }
    }
  }

  Widget configWidget(
    ConfigurationStorage config,
    VoidCallback setState,
  ) {
    return _pace;
  }

  Widget runningWidget(double durationS, VoidCallback setState) {
    return Visibility(
      visible: _feedback.hasEntry(),
      child: DropdownButton<int>(
        value: _soundIntervalS,
        icon: const Icon(Icons.arrow_downward),
        elevation: 16,
        style: const TextStyle(color: Colors.deepPurple),
        underline: Container(height: 2, color: Colors.deepPurpleAccent),
        onChanged: (int? value) {
          _soundIntervalS = value!;
          _nextSoundS = (durationS + _soundIntervalS).toInt();
          setState();
        },
        items:
            [5, 15, 30, 45, 60, 3600]
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text("$value s"),
                  ),
                )
                .toList(),
      ),
    );
  }
}
