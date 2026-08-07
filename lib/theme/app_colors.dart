import 'package:flutter/material.dart';

/// The design system, locked for the project's lifecycle.
/// Same hex values as the mobile app — do not fork these.
class AppColors {
  AppColors._();

  // Surfaces
  static const bg = Color(0xFF141414);
  static const surface = Color(0xFF1E1E1E);
  static const fill = Color(0xFF242424);
  static const border = Color(0xFF383838);

  // Text
  static const text = Color(0xFFEDEDED);
  static const text2 = Color(0xFFA8A8A8);
  static const muted = Color(0xFF8A8A8A);

  // Brand + status
  static const green = Color(0xFF2E7D32);
  static const greenLight = Color(0xFF7BC67E);
  static const greenDark = Color(0xFF1E4620);
  static const orange = Color(0xFFE05B4D); // error / unsynced
  static const amber = Color(0xFFE0A54D); // pending / attention
  static const amberDark = Color(0xFF4A2A1A);

  /// Score ramp, index 0 = score 1, index 4 = score 5.
  static const scoreRamp = <Color>[
    Color(0xFFE05B4D),
    Color(0xFFE08A4D),
    Color(0xFFD9B84D),
    Color(0xFF6FA84F),
    Color(0xFF2E7D32),
  ];

  /// Colour for a single section score (1–5).
  static Color forSectionScore(num score) {
    final i = (score.round() - 1).clamp(0, 4);
    return scoreRamp[i];
  }

  /// Colour for a total score (0–35), mapped back onto the 1–5 ramp.
  static Color forTotalScore(num total) => forSectionScore(total / 7);
}