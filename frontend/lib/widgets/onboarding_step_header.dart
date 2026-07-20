import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// The chunky header used across the three Trust Gateway onboarding steps.
///
/// Shows a colored step pill (e.g. "STEP 1 · VERIFY YOUR WORK"), a big
/// Archivo Black title, and an optional subtitle.
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    this.accent = Palette.cobalt,
  });

  final String step;
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: accent,
            border: Border.all(color: Palette.ink, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                  color: Palette.ink, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            '$step · ${title.toUpperCase()}',
            style: AppType.mono(
                size: 12,
                color: accent == Palette.mustard || accent == Palette.lime
                    ? Palette.ink
                    : Palette.paper,
                weight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: AppType.display(size: 34, height: 0.98)),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!,
              style: AppType.body(
                  size: 15, height: 1.35, color: Palette.ink600)),
        ],
      ],
    );
  }
}
