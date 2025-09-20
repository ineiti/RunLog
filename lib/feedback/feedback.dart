import 'dart:convert';

import 'package:collection/collection.dart';

import 'tones.dart';

enum FeedbackType { none, pace, slope }

enum _FeedbackFields { type, slopeMult, target }

class FeedbackContainer {
  final FeedbackType type;
  final List<double> slopeMult;
  final SFEntry target;

  static FeedbackContainer fromPace(SFEntry target) {
    return FeedbackContainer(FeedbackType.pace, [1], target);
  }

  static FeedbackContainer fromSlopeMult(
    SFEntry target,
    List<double> slopeMult,
  ) {
    return FeedbackContainer(FeedbackType.pace, slopeMult, target);
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

    final slopeMult =
        (map[_FeedbackFields.slopeMult.name] as List<dynamic>?)
            ?.map<double>((e) => e.toDouble())
            .toList() ??
        [1.0];

    return FeedbackContainer(
      fbt,
      slopeMult,
      SFEntry.fromJson(map[_FeedbackFields.target.name] ?? "[]"),
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
        ListEquality<double>().equals(other.slopeMult, slopeMult) &&
        other.target == target;
  }

  @override
  int get hashCode => type.hashCode ^ slopeMult.hashCode ^ target.hashCode;
}
