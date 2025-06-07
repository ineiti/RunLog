import 'package:flutter/material.dart';

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
