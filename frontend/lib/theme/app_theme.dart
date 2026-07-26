import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// Assembles the app-wide [ThemeData] for the Soft Brutalist look.
///
/// The theme sets the warm cream background, ink as the primary text color,
/// and Inter Tight as the default text face. Individual brutalist widgets
/// layer on the thick borders / hard shadows themselves.
abstract final class AppTheme {
  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: Palette.teal,
      primary: Palette.teal,
      onPrimary: Palette.paper,
      surface: Palette.paper,
      onSurface: Palette.ink,
      brightness: Brightness.light,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Palette.cream50,
      canvasColor: Palette.cream50,
      textTheme: GoogleFonts.interTightTextTheme(base.textTheme).apply(
        bodyColor: Palette.ink,
        displayColor: Palette.ink,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Palette.teal,
        selectionColor: Palette.ink200,
        selectionHandleColor: Palette.teal,
      ),
    );
  }
}
