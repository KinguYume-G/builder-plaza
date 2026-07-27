import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/project_card.dart';
import '../../state/growth_provider.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_dropdown.dart';
import '../../widgets/brutal_scaffold.dart';
import '../../widgets/growth_post_card.dart';
import '../../widgets/project_list_card.dart';

/// Standalone `/plaza` route: the discovery feed wrapped in a title bar.
class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrutalScaffold(
      title: 'The Plaza',
      titleBarColor: Palette.lime,
      body: PlazaBody(),
    );
  }
}

/// The Plaza discovery feed: a stage filter row, a search field, and a list of
/// active project cards. Scaffold-less so it can be embedded as a Home tab or
/// wrapped by [DiscoveryScreen].
class PlazaBody extends StatefulWidget {
  const PlazaBody({super.key});

  @override
  State<PlazaBody> createState() => _PlazaBodyState();
}

class _PlazaBodyState extends State<PlazaBody> {
  final _searchController = TextEditingController();
  String? _stageFilter;

  /// Feed mode: false = project discovery, true = F4 growth feed.
  bool _growthMode = false;

  /// Growth-feed owner-role filter (builder/collaborator/founder), or null.
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    if (_growthMode) {
      return context
          .read<GrowthProvider>()
          .fetchFeed(role: _roleFilter, stage: _stageFilter);
    }
    return context.read<ProjectsProvider>().fetchDiscovery(
          stage: _stageFilter,
          q: _searchController.text.trim(),
        );
  }

  void _setMode(bool growth) {
    if (_growthMode == growth) return;
    setState(() => _growthMode = growth);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectsProvider>();
    final growth = context.watch<GrowthProvider>();

    return RefreshIndicator(
      color: Palette.ink,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Real projects in progress, and the code-driven updates behind '
            'them',
            style: AppType.body(size: 13, color: Palette.ink600),
          ),
          const SizedBox(height: 16),
          // Mode + the mode-specific secondary filter, one line: dropdowns
          // instead of badge rows so this doesn't eat vertical space, and a
          // search field (project mode only) fills whatever's left.
          Row(
            children: [
              BrutalDropdown<bool>(
                value: _growthMode,
                items: const [(false, 'Projects'), (true, 'Growth')],
                onChanged: _setMode,
              ),
              const SizedBox(width: 8),
              if (_growthMode)
                Expanded(
                  child: BrutalDropdown<String?>(
                    expanded: true,
                    value: _roleFilter,
                    items: const [
                      (null, 'All roles'),
                      ('builder', 'Builder'),
                      ('collaborator', 'Collaborator'),
                      ('founder', 'Founder'),
                    ],
                    onChanged: (role) {
                      setState(() => _roleFilter = role);
                      _refresh();
                    },
                  ),
                )
              else ...[
                BrutalDropdown<String?>(
                  value: _stageFilter,
                  items: [
                    (null, 'All stages'),
                    for (final stage in kStages) (stage, stageLabel(stage)),
                  ],
                  onChanged: (stage) {
                    setState(() => _stageFilter = stage);
                    _refresh();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppType.body(size: 13, weight: FontWeight.w500),
                    cursorColor: Palette.teal,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _refresh(),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: AppType.body(size: 13, color: Palette.ink400),
                      isDense: true,
                      filled: true,
                      fillColor: Palette.paper,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: Palette.ink, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: Palette.teal, width: 2.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // NFR: make it visible when the feed is served from the offline cache.
          if ((_growthMode && growth.feedFromCache) ||
              (!_growthMode && provider.discoveryFromCache)) ...[
            const BrutalBadge(
                label: 'OFFLINE · SHOWING CACHED FEED', color: Palette.ink200),
            const SizedBox(height: 12),
          ],
          if (_growthMode) ...[
            if (growth.loadingFeed && growth.feed.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                    child: CircularProgressIndicator(color: Palette.ink)),
              )
            else if (growth.feed.isEmpty)
              _EmptyState(
                  error: growth.error ??
                      'No growth updates yet. Project owners can post one '
                          'from their project page with "Refresh growth".')
            else
              for (final item in growth.feed) ...[
                GrowthPostCard(
                  post: item.post,
                  projectTitle: item.projectTitle,
                  ownerLogin: item.owner.githubLogin,
                  onTap: () =>
                      context.push('/projects/${item.post.projectId}'),
                ),
                const SizedBox(height: 14),
              ],
          ] else ...[
          if (provider.loadingDiscovery && provider.discovery.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                  child: CircularProgressIndicator(color: Palette.ink)),
            )
          else if (provider.discovery.isEmpty)
            _EmptyState(error: provider.error)
          else
            for (final project in provider.discovery) ...[
              ProjectListCard(
                project: project,
                onTap: () => context.push('/projects/${project.id}'),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}

/// A plain placeholder line -- not a card, just background text -- since
/// "nothing matched" doesn't need its own bordered block to say so.
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          error ??
              'Nothing matches your filters yet. Try clearing the stage or search.',
          textAlign: TextAlign.center,
          style: AppType.body(size: 14, color: Palette.ink400, height: 1.4),
        ),
      ),
    );
  }
}
