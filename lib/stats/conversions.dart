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

double speedMinKm(double mps) {
  if (mps <= 0) {
    return mps;
  }
  return 1000 / 60 / mps;
}

