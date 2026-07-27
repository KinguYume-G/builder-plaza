import 'package:flutter/animation.dart';

/// Motion Budget: every duration/curve used for purposeful, non-decorative
/// animation lives here as a single source of truth.
///
/// Deliberately narrow — animations outside this budget (persistent pulsing
/// dots, decorative shimmer/sparkle, always-on ambient motion) are not
/// implemented anywhere in the app. Every entry below exists to confirm a
/// state change (pressed, loading, arrived), never to decorate.
abstract final class AppMotion {
  /// Press/tap feedback on buttons and cards — must read as instant.
  static const Duration press = Duration(milliseconds: 120);

  /// One-shot entrance fade for freshly-loaded list content.
  static const Duration fadeIn = Duration(milliseconds: 200);

  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1.0);
}
