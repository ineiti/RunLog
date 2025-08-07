import 'package:flutter/material.dart';
import 'package:run_log/running/tones.dart';

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
      case FeedbackType.runDuration:
        // TODO: Handle this case.
        throw UnimplementedError();
      case FeedbackType.runPace:
        // TODO: Handle this case.
        throw UnimplementedError();
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

  List<Widget> configWidget(VoidCallback setState) {
    return [
      Row(
        children: [
          Text("  Tone Feedback: "),
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
        child: _configParam(setState),
      ),
    ];
  }

  Widget _configParam(VoidCallback setState) {
    if (_feedbackSound == FeedbackType.none) {
      return Text("Shouldn't happen");
    }
    final List<Widget> col = [];
    if (_feedbackSound == FeedbackType.pace ||
        _feedbackSound == FeedbackType.runPace) {
      col.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Flexible(
              flex: 2,
              fit: FlexFit.tight,
              child: Text("  ${minSec(_feedbackPace)} min/km"),
            ),
            Flexible(
              flex: 5,
              fit: FlexFit.tight,
              child: Slider(
                value: _feedbackPace,
                onChanged: (double value) {
                  _feedbackPace = value;
                  setState();
                },
                min: 5,
                divisions: 24,
                max: 7,
              ),
            ),
          ],
        ),
      );
    } else {
      col.add(
        Row(
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
        ),
      );
    }
    if (_feedbackSound == FeedbackType.runDuration ||
        _feedbackSound == FeedbackType.runPace) {

      col.add(
        DropdownButton(
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
        ),
      );
    }
    return Column(children: col);
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

