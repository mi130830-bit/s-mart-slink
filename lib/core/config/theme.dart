import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.teal,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey.shade50,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.teal,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF121212),
  );
}
