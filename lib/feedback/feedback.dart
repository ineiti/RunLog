import 'dart:convert';

import 'tones.dart';

enum FeedbackType { none, pace, slope }

enum _FeedbackFields { type, slopeMult, target }

class FeedbackContainer {
  final FeedbackType type;
  final double slopeMult;
  final SFEntry target;

  static FeedbackContainer fromPace(SFEntry target){
    return FeedbackContainer(FeedbackType.pace, 1, target);
  }

  static FeedbackContainer fromSlopeMult(SFEntry target, double slopeMult){
    return FeedbackContainer(FeedbackType.pace, slopeMult, target);
  }

  static FeedbackContainer empty(){
    return FeedbackContainer.fromJson("{}");
  }

  static FeedbackContainer fromJson(String s) {
    final map = jsonDecode(s);
    return FeedbackContainer(
      map[_FeedbackFields.type.name] ?? FeedbackType.none,
      map[_FeedbackFields.slopeMult.name] ?? 1,
      map[_FeedbackFields.target.name] ?? SFEntry(),
    );
  }

  FeedbackContainer(this.type, this.slopeMult, this.target);

  String toJson() {
    return jsonEncode({
      _FeedbackFields.type.name: type.name,
      _FeedbackFields.slopeMult.name: slopeMult,
      _FeedbackFields.target.name: target.toJson(),
    });
  }


  String displayString() {
    switch (type) {
      case FeedbackType.none:
        return "No Feedback";
      case FeedbackType.pace:
        return "Preset Pace";
      case FeedbackType.slope:
        return "Slope Adjust";
    }
  }
}
