import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/growth_post.dart';
import '../../models/project_card.dart';
import '../../models/repo_activity.dart';
import '../../state/auth_provider.dart';
import '../../state/growth_provider.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';
import '../../widgets/growth_post_card.dart';
import '../login_screen.dart' show kRoleColors;

/// Full project detail: hero, owner, intent, needs, demo link, team division,
/// screenshot gallery, and live repo activity. Owners get edit/archive controls.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  ProjectCard? _card;
  List<RepoActivity>? _activity;
  List<GrowthPost>? _growth;
  bool _loading = true;
  bool _archiving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<ProjectsProvider>();
    try {
      final card = await provider.fetchOne(widget.projectId);
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
      });
      // Repo activity is best-effort and loaded after the card renders.
      if (card.repoFullNames.isNotEmpty) {
        final activity = await provider.fetchRepoActivity(widget.projectId);
        if (mounted) setState(() => _activity = activity);
      } else {
        setState(() => _activity = const []);
      }
      await _loadGrowth();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this project.';
      });
    }
  }

  /// Best-effort load of the F4 growth history; failures leave the section
  /// showing its empty state rather than erroring the whole screen.
  Future<void> _loadGrowth() async {
    try {
      final growth = await context
          .read<GrowthProvider>()
          .fetchProjectGrowth(widget.projectId);
      if (mounted) setState(() => _growth = growth);
    } catch (_) {
      if (mounted) setState(() => _growth = const []);
    }
  }

  Future<void> _refreshGrowth() async {
    final provider = context.read<GrowthProvider>();
    final post = await provider.refreshGrowth(widget.projectId);
    if (!mounted) return;
    if (post != null) {
      setState(() => _growth = [post, ...?_growth]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New growth update posted.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ??
                'No new GitHub activity since the last update.')),
      );
    }
  }

  Future<void> _archive() async {
    final confirmed = await _confirmArchive();
    if (confirmed != true || !mounted) return;
    setState(() => _archiving = true);
    final updated =
        await context.read<ProjectsProvider>().archiveProject(widget.projectId);
    if (!mounted) return;
    setState(() {
      _archiving = false;
      if (updated != null) _card = updated;
    });
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project archived.')),
      );
    }
  }

  Future<bool?> _confirmArchive() {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BrutalCard(
          accent: Palette.tomato,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ARCHIVE PROJECT?', style: AppType.display(size: 20)),
              const SizedBox(height: 10),
              Text(
                'It will be removed from the Plaza. You can still see it in '
                'your own projects.',
                style: AppType.body(size: 14, color: Palette.ink600),
              ),
              const SizedBox(height: 20),
              BrutalButton(
                label: 'Archive',
                color: Palette.tomato,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              BrutalButton(
                label: 'Cancel',
                color: Palette.cream100,
                textColor: Palette.ink,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyDemoUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied: $url')),
    );
  }

  void _enlarge(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            decoration: BoxDecoration(
              color: Palette.paper,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final isOwner = card != null && currentUserId == card.ownerId;

    return BrutalScaffold(
      title: 'Project',
      titleBarColor: card == null
          ? Palette.cobalt
          : (kRoleColors[card.owner.primaryRole] ?? Palette.cobalt),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Palette.ink))
          : card == null
              ? _errorBody()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _body(card, isOwner),
                    ),
                  ),
                ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BrutalCard(
          accent: Palette.tomato,
          child: Text(_error ?? 'Something went wrong.',
              style: AppType.body(size: 15, color: Palette.tomato)),
        ),
      ),
    );
  }

  Widget _body(ProjectCard card, bool isOwner) {
    final roleColor = kRoleColors[card.owner.primaryRole] ?? Palette.cobalt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero.
        Text(card.title, style: AppType.display(size: 30, height: 1.02)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BrutalBadge(
                label: stageLabel(card.stage),
                color: Palette.cobalt,
                textColor: Palette.paper),
            BrutalBadge(
              label: card.isArchived ? 'Archived' : 'Active',
              color: card.isArchived ? Palette.ink200 : Palette.lime,
            ),
            if (card.intent != null)
              BrutalBadge(
                  label: card.intent!.label,
                  color: Palette.plum,
                  textColor: Palette.paper),
          ],
        ),
        const SizedBox(height: 20),
        // Owner.
        BrutalCard(
          accent: roleColor,
          child: Row(
            children: [
              _Avatar(url: card.owner.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${card.owner.githubLogin}',
                        style: AppType.display(size: 18, height: 1.05),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    BrutalBadge(
                      label: card.owner.primaryRole,
                      color: roleColor,
                      textColor:
                          roleColor == Palette.cobalt ? Palette.paper : Palette.ink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (card.intent?.note != null && card.intent!.note!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'INTENT',
            child: Text(card.intent!.note!,
                style: AppType.body(size: 15, height: 1.35)),
          ),
        ],
        if (card.needs != null && card.needs!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'NEEDS',
            child: Text(card.needs!.trim(),
                style: AppType.body(size: 15, height: 1.35)),
          ),
        ],
        if (card.demoUrl != null && card.demoUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'DEMO',
            child: GestureDetector(
              onTap: () => _copyDemoUrl(card.demoUrl!.trim()),
              child: Text(
                card.demoUrl!.trim(),
                style: AppType.body(
                    size: 15,
                    color: Palette.cobalt,
                    weight: FontWeight.w700,
                    height: 1.3),
              ),
            ),
          ),
        ],
        if (card.teamDivision != null &&
            card.teamDivision!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'TEAM DIVISION',
            child: Text(card.teamDivision!.trim(),
                style: AppType.body(size: 15, height: 1.35)),
          ),
        ],
        if (card.screenshots.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'SCREENSHOTS',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final shot in card.screenshots)
                  GestureDetector(
                    onTap: () => _enlarge(shot.url),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Palette.cream100,
                        border: Border.all(color: Palette.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        shot.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.broken_image,
                            color: Palette.ink400),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (card.repoFullNames.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'LINKED REPOS',
            child: _RepoActivityList(
                repos: card.repoFullNames, activity: _activity),
          ),
        ],
        if (card.repoFullNames.isNotEmpty || (_growth?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'GROWTH',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isOwner && card.repoFullNames.isNotEmpty) ...[
                  BrutalButton(
                    label: 'Refresh growth',
                    color: Palette.lime,
                    textColor: Palette.ink,
                    loading: context.watch<GrowthProvider>().refreshing,
                    onPressed: context.watch<GrowthProvider>().refreshing
                        ? null
                        : _refreshGrowth,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_growth == null)
                  Text('Loading growth updates…',
                      style: AppType.mono(size: 12, color: Palette.ink400))
                else if (_growth!.isEmpty)
                  Text('No growth updates yet.',
                      style: AppType.mono(size: 12, color: Palette.ink400))
                else
                  for (final post in _growth!) ...[
                    GrowthPostCard(post: post),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ],
        if (isOwner) ...[
          const SizedBox(height: 28),
          BrutalButton(
            label: 'Edit',
            color: Palette.cobalt,
            onPressed: () => context.push('/projects/${card.id}/edit'),
          ),
          const SizedBox(height: 12),
          if (!card.isArchived)
            BrutalButton(
              label: 'Archive',
              color: Palette.tomato,
              loading: _archiving,
              onPressed: _archiving ? null : _archive,
            ),
        ],
      ],
    );
  }
}

/// A titled section: mono caption + content.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Renders each linked repo as a card. Uses live [activity] when available and
/// falls back to a muted "activity unavailable" line otherwise.
class _RepoActivityList extends StatelessWidget {
  const _RepoActivityList({required this.repos, required this.activity});

  final List<String> repos;
  final List<RepoActivity>? activity;

  RepoActivity? _forRepo(String repo) {
    final list = activity;
    if (list == null) return null;
    for (final a in list) {
      if (a.repo == repo) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loading = activity == null;
    return Column(
      children: [
        for (final repo in repos) ...[
          _RepoCard(repo: repo, activity: _forRepo(repo), loading: loading),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({
    required this.repo,
    required this.activity,
    required this.loading,
  });

  final String repo;
  final RepoActivity? activity;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final unavailable = !loading && (a == null || a.hasError);

    return BrutalCard(
      accent: unavailable ? Palette.ink400 : Palette.cobalt,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(repo, style: AppType.mono(size: 13, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (loading)
            Text('Loading activity…',
                style: AppType.mono(size: 12, color: Palette.ink400))
          else if (unavailable)
            Text('Activity unavailable',
                style: AppType.mono(size: 12, color: Palette.ink400))
          else ...[
            if (a!.description != null && a.description!.isNotEmpty) ...[
              Text(a.description!,
                  style:
                      AppType.body(size: 13, color: Palette.ink600, height: 1.3)),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (a.stars != null)
                  BrutalBadge(
                      label: '★ ${a.stars}', color: Palette.mustard),
                if (a.language != null && a.language!.isNotEmpty)
                  BrutalBadge(
                      label: a.language!,
                      color: Palette.paper,
                      textColor: Palette.ink),
                if (a.openIssues != null)
                  BrutalBadge(
                      label: '${a.openIssues} issues', color: Palette.lime),
                if (a.pushedAt != null)
                  BrutalBadge(
                      label: 'pushed ${_ago(a.pushedAt!)}',
                      color: Palette.paper,
                      textColor: Palette.ink),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Palette.cream100,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person, color: Palette.ink400)
          : Image.network(url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person, color: Palette.ink400)),
    );
  }
}
