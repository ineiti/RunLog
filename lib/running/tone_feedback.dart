import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';

import '../stats/conversions.dart';

class ToneFeedback {
  int _soundIntervalS = 5;
  bool _feedbackSound = false;
  double _feedbackPace = 5;
  int _lastSoundS = 0;
  int _maxFeedbackIndex = 4;
  final Tones _feedback;

  static Future<ToneFeedback> init() async {
    return ToneFeedback(feedback: await Tones.init());
  }

  ToneFeedback({required Tones feedback}) : _feedback = feedback;

  startRunning(int maxFeedbackIndex) async {
    _lastSoundS = _soundIntervalS;
    _maxFeedbackIndex = maxFeedbackIndex;
    if (_feedbackSound) {
      _feedback.setEntry(SFEntry.startMinKm(_feedbackPace));
    }
  }

  updateRunning(double durationS, double distanceM) async {
    if (_feedbackSound) {
      // print("${runStats!.duration()} / $lastSoundS");
      if (durationS >= _lastSoundS) {
        await _feedback.playSound(_maxFeedbackIndex, distanceM, durationS);
        while (_lastSoundS <= durationS) {
          _lastSoundS += _soundIntervalS;
        }
      }
    }
  }

  List<Widget> configWidget(VoidCallback setState) {
    return [
      CheckboxListTile(
        title: Text("Feedback sound"),
        value: _feedbackSound,
        onChanged: (bool? value) async {
          if (value != null) {
            _feedbackSound = value;
            setState();
          }
        },
      ),
      Visibility(
        visible: _feedbackSound,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Text("  ${minSec(_feedbackPace)} min/km"),
            Flexible(
              child: Slider(
                value: _feedbackPace,
                onChanged: (double value) {
                  _feedbackPace = value;
                  setState();
                },
                min: 2,
                divisions: 96,
                max: 10,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget runningWidget(double durationS, VoidCallback setState) {
    return Visibility(
      visible: _feedbackSound,
      child: DropdownButton<int>(
        value: _soundIntervalS,
        icon: const Icon(Icons.arrow_downward),
        elevation: 16,
        style: const TextStyle(color: Colors.deepPurple),
        underline: Container(height: 2, color: Colors.deepPurpleAccent),
        onChanged: (int? value) {
          _soundIntervalS = value!;
          _lastSoundS = (durationS + _soundIntervalS).toInt();
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
