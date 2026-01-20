import 'dart:async';

import 'package:flutter/material.dart';
import '../../feedback/feedback.dart';
import '../../stats/run_stats.dart';
import 'pace_widget.dart';
import '../../feedback/tones.dart';

import '../../configuration.dart';

class ToneFeedback {
  int _soundIntervalS = 15;
  final PaceWidget _pace;
  final StreamController<FeedbackContainer> _paceUpdates;
  int _nextSoundS = 0;
  int _maxFeedbackSilence = 4;
  final Tones tones;

  static Future<ToneFeedback> init() async {
    final paceUpdates = StreamController<FeedbackContainer>();
    return ToneFeedback(
      await Tones.init(),
      paceUpdates,
      PaceWidget(updateEntries: paceUpdates),
    );
  }

  ToneFeedback(this.tones, this._paceUpdates, this._pace) {
    _paceUpdates.stream.listen((update) => tones.setEntry(update.target));
  }

  Future<void> startRunning(int maxFeedbackSilence) async {
    _nextSoundS = _soundIntervalS;
    _maxFeedbackSilence = maxFeedbackSilence;
  }

  Future<void> updateRunning(
    bool announceChange,
    RunStats rs,
  ) async {
    if (tones.hasEntry()) {
      if (rs.durationSec() >= _nextSoundS) {
        await tones.playSound(
          _maxFeedbackSilence,
          announceChange,
          rs,
        );
        while (_nextSoundS <= rs.durationSec()) {
          _nextSoundS += _soundIntervalS;
        }
      }
    }
  }

  Widget configWidget() {
    return _pace;
  }

  Widget runningWidget(double durationS, VoidCallback setState) {
    return Visibility(
      visible: tones.hasEntry(),
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
