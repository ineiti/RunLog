import 'dart:convert';

import 'package:run_log/running/tones.dart';

enum FeedbackType { none, pace, runDuration, runPace }

enum _FeedbackFields { type, paceMinKm, durationS, target }

class Feedback {
  FeedbackType _type;
  double _paceMinKm;
  double _durationS;
  SFEntry _target;

  static Feedback init(){
    return Feedback.fromJson("{}");
  }

  static Feedback fromJson(String s) {
    final map = jsonDecode(s);
    return Feedback(
      map[_FeedbackFields.type.name] ?? FeedbackType.none,
      map[_FeedbackFields.paceMinKm.name] ?? 5,
      map[_FeedbackFields.durationS.name] ?? 0,
      map[_FeedbackFields.target.name] ?? SFEntry(),
    );
  }

  Feedback(this._type, this._paceMinKm, this._durationS, this._target);

  String toJson() {
    return jsonEncode({
      _FeedbackFields.type.name: _type.name,
      _FeedbackFields.paceMinKm.name: _paceMinKm,
      _FeedbackFields.durationS.name: _durationS,
      _FeedbackFields.target.name: _target.toJson(),
    });
  }
}

String ftDisplayString(FeedbackType ft) {
  switch (ft) {
    case FeedbackType.none:
      return "No Feedback";
    case FeedbackType.pace:
      return "Fixed Pace";
    case FeedbackType.runDuration:
      return "Duration Previous Run";
    case FeedbackType.runPace:
      return "Pace Previous Run";
  }
}

String? ftToString(FeedbackType? ft) {
  switch (ft) {
    case FeedbackType.none:
      return "None";
    case FeedbackType.pace:
      return "Pace";
    case FeedbackType.runDuration:
      return "RunDuration";
    case FeedbackType.runPace:
      return "RunPace";
    default:
      return null;
  }
}

FeedbackType? ftFromString(String? s) {
  switch (s) {
    case "None":
      return FeedbackType.none;
    case "Pace":
      return FeedbackType.pace;
    case "RunDuration":
      return FeedbackType.runDuration;
    case "RunPace":
      return FeedbackType.runPace;
    default:
      return null;
  }
}
