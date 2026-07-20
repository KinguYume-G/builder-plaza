import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// Typography for the Soft Brutalist design system.
///
/// Three faces:
/// - display  → Archivo Black (chunky editorial headlines)
/// - body     → Inter Tight (readable UI text)
/// - mono     → JetBrains Mono (numbers, codes, technical values)
///
/// Each helper wraps a [GoogleFonts] call. google_fonts falls back to the
/// platform default face automatically if the requested font can't be fetched
/// at runtime, so these are safe to use offline.
abstract final class AppType {
  /// Big editorial headline face.
  static TextStyle display({
    double size = 32,
    Color color = Palette.ink,
    double? height,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.archivoBlack(
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Default UI body face.
  static TextStyle body({
    double size = 16,
    Color color = Palette.ink,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.interTight(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Monospace face for numbers / codes / status values.
  static TextStyle mono({
    double size = 14,
    Color color = Palette.ink,
    FontWeight weight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }
}
