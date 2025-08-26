String timeHMS(double s) {
  final hours = (s / 60 / 60).toInt();
  final mins = (s / 60 % 60).toInt();
  final sec = (s % 60).toInt();
  if (hours > 0) {
    return "${hours}h ${mins}min ${sec}sec";
  } else if (mins > 0) {
    return "${mins}min ${sec}sec";
  } else {
    return "${sec}sec";
  }
}

String shortHMS(double s) {
  final hours = (s / 60 / 60).toInt();
  final mins = (s / 60 % 60).toInt();
  final sec = (s % 60).toInt();
  if (hours > 0) {
    return "${hours}h ${_intTwo(mins)}' ${_intTwo(sec)}''";
  } else if (mins > 0) {
    return "${_intTwo(mins)}' ${_intTwo(sec)}''";
  } else {
    return "${_intTwo(sec)}''";
  }
}

String _intTwo(int i){
  return i.toString().padLeft(2, "0");
}

double toPaceMinKm(double mps) {
  if (mps <= 0) {
    return mps;
  }
  return 1000 / 60 / mps;
}

double toSpeedMS(double minKm) {
  if (minKm <= 0) {
    return minKm;
  }
  return 1000 / 60 / minKm;
}

String labelYTime(String s) {
  return minSec(double.parse(s));
}

String minSec(double minutes) {
  if (!minutes.isFinite){
    return "NaN";
  }
  final min = minutes.toInt();
  final sec = ((minutes - min) * 60).round();
  return "$min' ${sec > 0 ? "$sec''" : ""}";
}

String minSecFix(double minutes, int fixMin) {
  final min = minutes.toInt();
  final sec = ((minutes - min) * 60).round();
  return "${min.toStringAsFixed(0).padLeft(fixMin, "0")}' ${sec.toStringAsFixed(0).padLeft(2, '0')}''";
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
