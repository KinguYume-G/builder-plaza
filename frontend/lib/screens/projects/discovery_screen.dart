import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/project_card.dart';
import '../../state/growth_provider.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_card.dart';
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

  void _toggleStage(String stage) {
    setState(() => _stageFilter = _stageFilter == stage ? null : stage);
    _refresh();
  }

  void _toggleRole(String role) {
    setState(() => _roleFilter = _roleFilter == role ? null : role);
    _refresh();
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
          // Projects ↔ Growth feed toggle.
          Row(
            children: [
              BrutalBadge(
                label: 'PROJECTS',
                color: Palette.lime,
                selected: !_growthMode,
                onTap: () => _setMode(false),
              ),
              const SizedBox(width: 8),
              BrutalBadge(
                label: 'GROWTH',
                color: Palette.mustard,
                selected: _growthMode,
                onTap: () => _setMode(true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_growthMode) ...[
            // Role filter for the growth feed.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final role in const [
                    'builder',
                    'collaborator',
                    'founder'
                  ]) ...[
                    BrutalBadge(
                      label: role,
                      color: Palette.mustard,
                      selected: _roleFilter == role,
                      onTap: () => _toggleRole(role),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
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
          // Search.
          TextField(
            controller: _searchController,
            style: AppType.body(size: 15, weight: FontWeight.w500),
            cursorColor: Palette.cobalt,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _refresh(),
            decoration: InputDecoration(
              hintText: 'Search projects…',
              hintStyle: AppType.body(size: 15, color: Palette.ink400),
              prefixIcon: Icon(Icons.search, color: Palette.ink400),
              filled: true,
              fillColor: Palette.paper,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Palette.ink, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Palette.cobalt, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Stage filter row.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final stage in kStages) ...[
                  BrutalBadge(
                    label: stageLabel(stage),
                    color: Palette.lime,
                    selected: _stageFilter == stage,
                    onTap: () => _toggleStage(stage),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: BrutalCard(
        background: Palette.cream100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOTHING HERE YET',
                style: AppType.display(size: 20)),
            const SizedBox(height: 8),
            Text(
              error ??
                  'No projects match your filters. Try clearing the stage or '
                      'search.',
              style: AppType.body(size: 14, color: Palette.ink600),
            ),
          ],
        ),
      ),
    );
  }
}
