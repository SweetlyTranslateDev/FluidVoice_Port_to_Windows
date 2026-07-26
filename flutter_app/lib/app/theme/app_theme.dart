import 'package:flutter/material.dart';

ThemeData buildFluidVoiceTheme() {
  const seed = Color(0xFF1B4D3E);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
