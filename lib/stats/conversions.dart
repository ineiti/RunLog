String timeHMS(double s) {
  final hours = (s / 60 / 60).toInt();
  final mins = (s / 60 % 60).toInt();
  final sec = (s % 60).toInt();
  if (hours > 0) {
    return "${hours}h ${mins}m ${sec}s";
  } else if (mins > 0) {
    return "${mins}m ${sec}s";
  } else {
    return "${sec}s";
  }
}

double paceMinKm(double mps) {
  if (mps <= 0) {
    return mps;
  }
  return 1000 / 60 / mps;
}

String labelYTime(String s) {
  final value = double.parse(s);
  final min = value.toInt();
  final sec = ((value - min) * 60).round();
  return "$min' ${sec > 0 ? " $sec''" : ""}";
}

String distanceStr(double m) {
  if (m < 1000) {
    return "${m.toInt()}m";
  } else if (m < 10000) {
    return "${(m / 1000).toStringAsFixed(2)}km";
  } else if (m < 100000) {
    return "${(m / 1000).toStringAsFixed(1)}km";
  } else {
    return "${(m / 1000).toInt()}km";
  }
}
