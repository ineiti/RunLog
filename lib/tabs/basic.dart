import 'package:flutter/material.dart';

import '../stats/conversions.dart';

Widget blueButton(String s, VoidCallback click) {
  return TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.lightBlue,
    ),
    onPressed: () {
      click();
    },
    child: Text(s),
  );
}

Widget paceSlider(
  ValueChanged<double> onPaceChanged,
  double pace,
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
          Text("${minSecFix(pace, 2)} / km"),
          Flexible(
            flex: 1,
            child: Slider(
              value: pace,
              onChanged: onPaceChanged,
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

class TimeHMS {
  int hours;
  int minutes;
  int seconds;
  final String label;

  TimeHMS(this.label, this.hours, this.minutes, this.seconds);

  Widget dropdownWidget(VoidCallback setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        Text(label),
        dropdown(List.generate(10, (i) => i), hours, (value) {
          hours = value;
          setState();
        }, (value) => "$value h"),
        dropdown(List.generate(60, (i) => i), minutes, (value) {
          minutes = value;
          setState();
        }, (value) => "$value m"),
        dropdown(List.generate(12, (i) => 5 * i), seconds, (value) {
          seconds = value;
          setState();
        }, (value) => "$value s"),
      ],
    );
  }

  int getSec() {
    return (hours * 60 + minutes) * 60 + seconds;
  }

  void setHMS(int h, int m, int s) {
    hours = h;
    minutes = m;
    seconds = s;
  }

  void setSec(int s) {
    seconds = (s % 60) ~/ 5 * 5;
    minutes = (s ~/ 60) % 60;
    hours = s ~/ 3600;
  }
}

class LengthKmM {
  int km;
  int m;
  final String label;

  LengthKmM(this.label, this.km, this.m);

  Widget dropdownWidget(VoidCallback setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        Text(label),
        dropdown(List.generate(40, (i) => i), km, (value) {
          km = value;
          setState();
        }, (value) => "$value km"),
        dropdown(List.generate(10, (i) => 100 * i), m, (value) {
          m = value;
          setState();
        }, (value) => "$value m"),
      ],
    );
  }

  void setM(int m) {
    km = m ~/ 1000;
    this.m = (m % 1000) ~/ 100 * 100;
  }

  int getM() {
    return km * 1000 + m;
  }
}

Widget dropdown<T>(
  List<T> values,
  T current,
  ValueChanged<T> update,
  String Function(T) formatter,
) {
  return DropdownButton(
    value: current,
    icon: const Icon(Icons.arrow_downward),
    elevation: 16,
    style: const TextStyle(color: Colors.deepPurple),
    underline: Container(height: 2, color: Colors.deepPurpleAccent),
    onChanged: (T? value) {
      if (value != null) {
        update(value);
      }
    },
    items:
        values
            .map(
              (value) => DropdownMenuItem<T>(
                value: value,
                child: Text(formatter(value)),
              ),
            )
            .toList(),
  );
}
