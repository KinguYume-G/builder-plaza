import 'package:flutter/material.dart';

import '../models/growth_post.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'brutal_badge.dart';
import 'brutal_card.dart';

/// One growth update in the plaza feed or a project's growth history.
///
/// When [projectTitle] is provided (plaza feed) it renders a header line with
/// the project and owner; in the project-detail history it is omitted.
class GrowthPostCard extends StatelessWidget {
  const GrowthPostCard({
    super.key,
    required this.post,
    this.projectTitle,
    this.ownerLogin,
    this.onTap,
  });

  final GrowthPost post;
  final String? projectTitle;
  final String? ownerLogin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eventTypes = <String>[];
    for (final event in post.sourceEvents) {
      if (!eventTypes.contains(event.typeLabel)) eventTypes.add(event.typeLabel);
    }

    return GestureDetector(
      onTap: onTap,
      child: BrutalCard(
        accent: Palette.lime,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (projectTitle != null)
                  Expanded(
                    child: Text(
                      projectTitle!,
                      style: AppType.display(size: 17, height: 1.05),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text('GROWTH UPDATE',
                      style: AppType.mono(
                          size: 11,
                          color: Palette.ink400,
                          weight: FontWeight.w700)),
                const Spacer(),
                if (post.createdAt != null)
                  Text(_ago(post.createdAt!),
                      style: AppType.mono(size: 11, color: Palette.ink400)),
              ],
            ),
            if (ownerLogin != null && ownerLogin!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('@$ownerLogin',
                  style: AppType.mono(size: 12, color: Palette.ink600)),
            ],
            const SizedBox(height: 12),
            Text(post.summary,
                style: AppType.body(size: 14, height: 1.4)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BrutalBadge(
                  label: '${post.sourceEvents.length} events',
                  color: Palette.mustard,
                ),
                for (final label in eventTypes.take(4))
                  BrutalBadge(
                      label: label,
                      color: Palette.paper,
                      textColor: Palette.ink),
                if (post.trigger == 'scheduled')
                  const BrutalBadge(label: 'AUTO', color: Palette.cream100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when.toLocal());
    if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
