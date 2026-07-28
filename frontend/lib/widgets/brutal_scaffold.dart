import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    this.isRootTab = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color background;

  /// Fill color of the chunky title bar. Defaults to cream; the Home shell
  /// tints it by the user's primary role.
  final Color titleBarColor;

  /// True for the Home shell's own tabs, which are legitimately the bottom of
  /// the stack. Everywhere else, an empty stack means the user was stranded by
  /// a route replacement and the title bar offers a way Home instead.
  final bool isRootTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              title: title,
              actions: actions,
              color: titleBarColor,
              isRootTab: isRootTab,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    this.actions,
    required this.color,
    required this.isRootTab,
  });

  final String title;
  final List<Widget>? actions;
  final Color color;
  final bool isRootTab;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    // A calm alpha-blended tint of the role/feature color instead of a full
    // vivid gradient fill -- the gradient title bar reads as a banner ad on
    // every single screen; a faint tint + a small accent dot still identifies
    // "which section am I in" without shouting on every navigation.
    final tint = Color.alphaBlend(color.withValues(alpha: 0.16), Palette.paper);
    return Container(
      decoration: BoxDecoration(
        color: tint,
        border: const Border(
          bottom: BorderSide(color: Palette.ink200, width: 1.25),
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
          ] else if (isRootTab) ...[
            // A tab of the home shell: nothing to go back to, so the dot is
            // pure section identity.
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ] else ...[
            // Not a root tab and nothing on the stack: the user got here
            // through a route replacement and has no way out but killing the
            // app. Offer Home rather than an inert decoration.
            GestureDetector(
              onTap: () => context.go('/home'),
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.home_filled, color: Palette.ink, size: 22),
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
