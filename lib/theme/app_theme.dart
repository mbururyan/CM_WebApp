import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Layout constants used by the shell.
class Layout {
  Layout._();

  /// Below this width the sidebar becomes a drawer.
  static const wideBreakpoint = 900.0;
  static const railWidth = 236.0;
  static const contentMaxWidth = 1240.0;
}

class AppTheme {
  AppTheme._();

  /// Monospaced, tabular figures. Every number in the dashboard uses this so
  /// columns of scores don't shift width as digits change.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
    double? letterSpacing,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small uppercase label used above numbers and section headings.
  static TextStyle get eyebrow => GoogleFonts.ibmPlexMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
        letterSpacing: 1.1,
      );

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.border,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.bg,
        onSurface: AppColors.text,
        primary: AppColors.green,
        onPrimary: Colors.white,
        secondary: AppColors.greenLight,
        error: AppColors.orange,
        outline: AppColors.border,
      ),
      textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.green, width: 1.4),
        errorBorder: _inputBorder(AppColors.orange),
        focusedErrorBorder: _inputBorder(AppColors.orange, width: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.fill,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border),
        radius: const Radius.circular(8),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}