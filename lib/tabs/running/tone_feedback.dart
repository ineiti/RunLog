import 'dart:async';

import 'package:flutter/material.dart';
import 'feedback.dart';
import 'feedback_track.dart';
import 'tones.dart';

import '../../configuration.dart';

class ToneFeedback {
  int _soundIntervalS = 15;
  final PaceWidget _pace;
  final StreamController<FeedbackContainer> _paceUpdates;
  int _nextSoundS = 0;
  int _maxFeedbackSilence = 4;
  final Tones _tones;

  static Future<ToneFeedback> init() async {
    final paceUpdates = StreamController<FeedbackContainer>();
    return ToneFeedback(
      await Tones.init(),
      paceUpdates,
      PaceWidget(updateEntries: paceUpdates),
    );
  }

  ToneFeedback(this._tones, this._paceUpdates, this._pace){
    _paceUpdates.stream.listen((update) => _tones.setEntry(update.target));
  }

  startRunning(int maxFeedbackSilence) async {
    _nextSoundS = _soundIntervalS;
    _maxFeedbackSilence = maxFeedbackSilence;
  }

  updateRunning(double durationS, double distanceM) async {
    if (_tones.hasEntry()) {
      // print("${runStats!.duration()} / $lastSoundS");
      if (durationS >= _nextSoundS) {
        await _tones.playSound(_maxFeedbackSilence, distanceM, durationS);
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
      visible: _tones.hasEntry(),
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
