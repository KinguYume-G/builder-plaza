import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A Scaffold wrapper with a chunky brutalist title bar.
///
/// The title bar sits on cream with an Archivo Black title and a thick 2px ink
/// bottom border separating it from the body.
class BrutalScaffold extends StatelessWidget {
  const BrutalScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.background = Palette.cream50,
    this.titleBarColor = Palette.cream100,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color background;

  /// Fill color of the chunky title bar. Defaults to cream; the Home shell
  /// tints it by the user's primary role.
  final Color titleBarColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(title: title, actions: actions, color: titleBarColor),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, this.actions, required this.color});

  final String title;
  final List<Widget>? actions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Container(
      decoration: BoxDecoration(
        gradient: Palette.glow(color),
        border: const Border(
          bottom: BorderSide(color: Palette.ink, width: 2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.arrow_back, color: Palette.ink, size: 22),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppType.display(size: 20, letterSpacing: -0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 12),
            ...actions!,
          ],
        ],
      ),
    );
  }
}
