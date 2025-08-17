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

