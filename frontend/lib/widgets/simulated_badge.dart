import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// F9: the ONE badge every mocked surface must carry (academic integrity —
/// simulated capabilities can never be mistaken for live ones).
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key, this.label = 'SIMULATED'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Palette.tomato,
        border: Border.all(color: Palette.ink, width: 1.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science, size: 12, color: Palette.paper),
          const SizedBox(width: 4),
          Text(label,
              style: AppType.mono(
                  size: 9,
                  weight: FontWeight.w800,
                  color: Palette.paper)),
        ],
      ),
    );
  }
}
