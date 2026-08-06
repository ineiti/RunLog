import 'dart:convert';

import 'tones.dart';

enum FeedbackType { none, pace, slope }

enum _FeedbackFields { type, target }

class FeedbackContainer {
  final FeedbackType type;
  final SFEntry target;

  static FeedbackContainer fromPace(SFEntry target) {
    return FeedbackContainer(FeedbackType.pace, target);
  }

  static FeedbackContainer empty() {
    return FeedbackContainer.fromJson("{}");
  }

  static FeedbackContainer fromJson(String s) {
    final map = jsonDecode(s);
    final fbt = FeedbackType.values.firstWhere(
      (e) => e.name == map[_FeedbackFields.type.name],
      orElse: () => FeedbackType.none,
    );

    return FeedbackContainer(
      fbt,
      SFEntry.fromJson(map[_FeedbackFields.target.name] ?? "[]"),
    );
  }

  FeedbackContainer(this.type, this.target);

  String toJson() {
    return jsonEncode({
      _FeedbackFields.type.name: type.name,
      _FeedbackFields.target.name: target.toJson(),
    });
  }

  @override
  String toString() {
    switch (type) {
      case FeedbackType.none:
        return "No Feedback";
      case FeedbackType.pace:
        return "Preset Pace $target";
      case FeedbackType.slope:
        return "Slope Adjust with $target";
    }
  }

  @override
  bool operator ==(Object other) {
    return other is FeedbackContainer &&
        other.type == type &&
        other.target == target;
  }

  @override
  int get hashCode => type.hashCode ^ target.hashCode;
}
