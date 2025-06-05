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
