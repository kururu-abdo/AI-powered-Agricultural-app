import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF286344)),
    scaffoldBackgroundColor: const Color(0xFFF7F9F5),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}
