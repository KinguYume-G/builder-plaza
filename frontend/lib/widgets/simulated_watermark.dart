import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A very visible "SIMULATED FOR DEMO" overlay for the mock LinkedIn consent
/// screen — an academic-integrity requirement so the screen can NEVER be
/// mistaken for the real LinkedIn.
///
/// Two layers:
///  1. A faint diagonal tile of repeated "SIMULATED FOR DEMO" text painted
///     across the whole surface (ignores pointer events).
///  2. A bold mustard diagonal corner ribbon in the top-right.
class SimulatedWatermark extends StatelessWidget {
  const SimulatedWatermark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        // Faint repeated diagonal text across everything.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _DiagonalTextPainter()),
          ),
        ),
        // Bold corner ribbon.
        const Positioned(
          top: 22,
          right: -54,
          child: IgnorePointer(child: _CornerRibbon()),
        ),
      ],
    );
  }
}

class _CornerRibbon extends StatelessWidget {
  const _CornerRibbon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4, // 45°
      child: Container(
        width: 220,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Palette.mustard,
          border: Border(
            top: BorderSide(color: Palette.ink, width: 2),
            bottom: BorderSide(color: Palette.ink, width: 2),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'SIMULATED FOR DEMO',
          style: AppType.mono(
              size: 11, weight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }
}

/// Paints faint, repeated, diagonal "SIMULATED FOR DEMO" text tiled across the
/// canvas so the whole screen reads as a non-production mockup.
class _DiagonalTextPainter extends CustomPainter {
  static const _text = 'SIMULATED FOR DEMO';

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: _text,
        style: AppType.mono(
          size: 18,
          weight: FontWeight.w700,
          color: Palette.ink.withValues(alpha: 0.06),
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Rotate the whole canvas so rows of text run diagonally.
    canvas.translate(0, 0);
    canvas.rotate(-math.pi / 9); // ~ -20°

    const dx = 260.0;
    const dy = 90.0;
    // Over-scan bounds so the rotated tiling still covers all corners.
    for (double y = -size.height; y < size.height * 1.6; y += dy) {
      for (double x = -size.width; x < size.width * 1.6; x += dx) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
