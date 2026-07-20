import 'package:flutter/material.dart';

import '../models/project_card.dart';
import '../screens/login_screen.dart' show kRoleColors;
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'brutal_badge.dart';
import 'brutal_card.dart';

/// A tappable summary card for one project, shared by the Plaza feed and the
/// Home "my projects" list. Shows title, stage, owner, a needs excerpt, the
/// owner's intent badge, and the first screenshot thumbnail.
class ProjectListCard extends StatelessWidget {
  const ProjectListCard({
    super.key,
    required this.project,
    required this.onTap,
    this.showOwner = true,
  });

  final ProjectCard project;
  final VoidCallback onTap;
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final roleColor =
        kRoleColors[project.owner.primaryRole] ?? Palette.cobalt;
    final thumb =
        project.screenshots.isNotEmpty ? project.screenshots.first.url : null;

    return GestureDetector(
      onTap: onTap,
      child: BrutalCard(
        accent: project.isArchived ? Palette.ink400 : roleColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumb != null) ...[
                  _Thumb(url: thumb),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        style: AppType.display(size: 18, height: 1.05),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          BrutalBadge(
                            label: stageLabel(project.stage),
                            color: Palette.cobalt,
                            textColor: Palette.paper,
                          ),
                          if (project.isArchived)
                            const BrutalBadge(
                                label: 'Archived', color: Palette.ink200),
                          if (project.intent != null)
                            BrutalBadge(
                              label: project.intent!.label,
                              color: Palette.plum,
                              textColor: Palette.paper,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showOwner) ...[
              const SizedBox(height: 10),
              Text('@${project.owner.githubLogin}',
                  style: AppType.mono(size: 12, color: Palette.ink600)),
            ],
            if (project.needs != null && project.needs!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                project.needs!.trim(),
                style: AppType.body(size: 14, height: 1.3, color: Palette.ink600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Palette.cream100,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.image_not_supported, color: Palette.ink400, size: 20),
      ),
    );
  }
}
