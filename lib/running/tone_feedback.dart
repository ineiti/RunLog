import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';

import '../configuration.dart';
import '../stats/conversions.dart';
import '../stats/run_data.dart';
import 'feedback.dart';

class ToneFeedback {
  int _soundIntervalS = 5;
  FeedbackType _feedbackSound = FeedbackType.none;
  double _feedbackPace = 5;
  int _feedbackDuration = 0;
  Run? _feedbackRun;
  int _nextSoundS = 0;
  int _maxFeedbackSoundWait = 4;
  final Tones _feedback;

  static Future<ToneFeedback> init() async {
    return ToneFeedback(await Tones.init());
  }

  ToneFeedback(this._feedback);

  startRunning(int maxFeedbackSoundWait) async {
    _nextSoundS = _soundIntervalS;
    _maxFeedbackSoundWait = maxFeedbackSoundWait;
    switch (_feedbackSound) {
      case FeedbackType.none:
        break;
      case FeedbackType.pace:
        _feedback.setEntry(SFEntry.startMinKm(_feedbackPace));
    }
  }

  updateRunning(double durationS, double distanceM) async {
    if (_feedbackSound != FeedbackType.none) {
      // print("${runStats!.duration()} / $lastSoundS");
      if (durationS >= _nextSoundS) {
        await _feedback.playSound(_maxFeedbackSoundWait, distanceM, durationS);
        while (_nextSoundS <= durationS) {
          _nextSoundS += _soundIntervalS;
        }
      }
    }
  }

  List<Widget> configWidget(
    ConfigurationStorage config,
    VoidCallback setState,
  ) {
    return [
      Row(
        children: [
          Text("Tone Feedback: "),
          DropdownButton<FeedbackType>(
            value: _feedbackSound,
            icon: const Icon(Icons.arrow_downward),
            elevation: 16,
            style: const TextStyle(color: Colors.deepPurple),
            underline: Container(height: 2, color: Colors.deepPurpleAccent),
            onChanged: (FeedbackType? value) {
              _feedbackSound = value!;
              setState();
            },
            items:
                FeedbackType.values
                    .map(
                      (value) => DropdownMenuItem<FeedbackType>(
                        value: value,
                        child: Text(ftDisplayString(value)),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
      Visibility(
        visible: _feedbackSound != FeedbackType.none,
        child: _configParam(config, setState),
      ),
    ];
  }

  Widget _configParam(ConfigurationStorage config, VoidCallback setState) {
    if (_feedbackSound == FeedbackType.none) {
      return Text("Shouldn't happen");
    }
    final List<Widget> col = [];
    col.add(
      _paceSlider(
        setState,
        "Overall Pace",
        config.config.minFeedbackPace,
        config.config.maxFeedbackPace,
      ),
    );
    return Column(children: col);
  }

  Widget _paceSlider(
    VoidCallback setState,
    String label,
    double from,
    double to,
  ) {
    final divisions = ((to - from) * 12).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text(label)]),
        Row(
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // spacing: 10,
          children: [
            Text("${minSecFix(_feedbackPace, 2)} / km"),
            Flexible(
              flex: 1,
              child: Slider(
                value: _feedbackPace,
                onChanged: (double value) {
                  _feedbackPace = value;
                  setState();
                },
                min: from,
                divisions: divisions,
                max: to,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timeDropdown(VoidCallback setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        _dropdown(
          List.generate(10, (i) => i),
          () => _feedbackDuration ~/ 3600,
          (value) {
            _feedbackDuration %= 3600;
            _feedbackDuration += value * 3600;
            setState();
          },
        ),
        _dropdown(
          List.generate(60, (i) => i),
          () => (_feedbackDuration ~/ 60) % 60,
          (value) {
            final minutes = (_feedbackDuration ~/ 60) % 60;
            _feedbackDuration += (value - minutes) * 60;
            setState();
          },
        ),
        _dropdown(
          List.generate(12, (i) => 5 * i),
          () => _feedbackDuration % 60,
          (value) {
            final seconds = _feedbackDuration % 60;
            _feedbackDuration += value - seconds;
            setState();
          },
        ),
      ],
    );
  }

  Widget _dropdown(
    List<int> values,
    int Function() value,
    void Function(int) update,
  ) {
    return DropdownButton(
      value: value(),
      icon: const Icon(Icons.arrow_downward),
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(height: 2, color: Colors.deepPurpleAccent),
      onChanged: (int? value) {
        if (value != null) {
          update(value);
        }
      },
      items:
          values
              .map(
                (value) => DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                ),
              )
              .toList(),
    );
  }

  Widget runningWidget(double durationS, VoidCallback setState) {
    return Visibility(
      visible: _feedbackSound != FeedbackType.none,
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
