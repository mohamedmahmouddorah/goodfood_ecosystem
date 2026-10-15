  import 'package:flutter/material.dart';

/// TEMP: replace with core/constants/app_colors.dart once the team pushes it.
abstract final class MenuPalette {
  static const bg = Color(0xFF020F14);
  static const surface = Color(0xFF07181F);
  static const border = Color(0xFF12303A);
  static const gold = Color(0xFFF5B84A);
  static const goldDark = Color(0xFFDE9B2B);
  static const muted = Color(0xFF8A9BA3);
  static const success = Color(0xFF1FD1A1);
  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gold, goldDark],
  );
}