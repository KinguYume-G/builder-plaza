import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/github_summary.dart';
import '../../models/project_card.dart';
import '../../models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_dropdown.dart';
import '../../widgets/brutal_scaffold.dart';
import '../matches/matches_screen.dart';
import '../projects/discovery_screen.dart';

/// The one shared Home shell for every role (PRD: shared pages implemented
/// once). Below [kWideLayoutBreakpoint] a brutalist bottom nav switches
/// between four tabs; at or above it, the same four destinations move into
/// a side rail so the tab strip stops eating vertical space on tablet/
/// desktop/web:
///   0 · Home     — the user's own projects + collaboration intent
///   1 · Plaza    — the public discovery feed
///   2 · Match    — F5 matching results
///   3 · Profile  — identity summary, GitHub activity, switch role, logout
///
/// Builders land on Home; Collaborators / Founders lead with the Plaza (they're
/// here to discover projects, not post them).

/// Shared nav destinations for both the narrow bottom nav and the wide side
/// rail, so the two layouts can never drift out of sync with each other.
const _kNavItems = [
  (Icons.home_filled, 'Home'),
  (Icons.grid_view, 'Plaza'),
  (Icons.join_inner, 'Match'),
  (Icons.person, 'Profile'),
];

/// Cycling palette for the top-languages bar segments/legend dots.
const _langColors = [
  Palette.teal,
  Palette.tomato,
  Palette.mustard,
  Palette.lime,
  Palette.copper,
];

/// Viewport width at which [HomeShell] switches from a bottom nav (phones)
/// to a side rail (tablet/desktop/web) — dev doc §15's mobile/wide split.
const double kWideLayoutBreakpoint = 700;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int? _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    // Refresh the user + their projects + intent on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final projects = context.read<ProjectsProvider>();
      auth.loadMe();
      if (auth.githubSummary == null) auth.loadGithubSummary();
      projects.fetchMine();
      projects.getIntent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final roleColor = user == null
        ? Palette.copper
        : (kRoleColors[user.primaryRole] ?? Palette.copper);

    // Default tab depends on the role, which arrives asynchronously. Derive it
    // read-only here — assigning to _index during build() mutates state in the
    // middle of a frame, which is exactly what Flutter tells you not to do.
    // _index is only ever written from the tab-tap handler.
    final index =
        _index ?? ((user != null && user.primaryRole == 'builder') ? 0 : 1);

    if (user == null) {
      return const BrutalScaffold(
        title: 'Home',
        isRootTab: true,
        titleBarColor: Palette.copper,
        body: Center(child: CircularProgressIndicator(color: Palette.ink)),
      );
    }

    final titles = [
      _roleTitle(user.primaryRole),
      'The Plaza',
      'Matches',
      'Profile',
    ];
    final barColors = [roleColor, Palette.lime, Palette.teal, roleColor];

    return BrutalScaffold(
      title: titles[index],
      isRootTab: true,
      titleBarColor: barColors[index],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tabs = IndexedStack(
            index: index,
            children: [
              _HomeTab(user: user, roleColor: roleColor),
              const PlazaBody(),
              const MatchesBody(),
              _ProfileTab(user: user, roleColor: roleColor),
            ],
          );

          if (constraints.maxWidth >= kWideLayoutBreakpoint) {
            // Tablet/desktop/web: a side rail replaces the bottom nav so
            // the tab strip doesn't eat vertical space on a wide viewport.
            return Row(
              key: const Key('home_shell_wide_layout'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SideRail(
                  index: index,
                  accent: roleColor,
                  onTap: (i) => setState(() => _index = i),
                ),
                Expanded(child: tabs),
              ],
            );
          }

          return Column(
            key: const Key('home_shell_narrow_layout'),
            children: [
              Expanded(child: tabs),
              _BottomNav(
                index: index,
                accent: roleColor,
                onTap: (i) => setState(() => _index = i),
              ),
            ],
          );
        },
      ),
    );
  }

  String _roleTitle(String role) => switch (role) {
        'builder' => 'Builder Home',
        'collaborator' => 'Collaborator Home',
        'founder' => 'Founder Home',
        _ => 'Home',
      };
}

// -----------------------------------------------------------------------------
// Home tab: my projects + intent
// -----------------------------------------------------------------------------

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.user, required this.roleColor});

  final User user;
  final Color roleColor;

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectsProvider>();
    final intent = projects.myIntent;

    return RefreshIndicator(
      color: Palette.ink,
      onRefresh: () => context.read<ProjectsProvider>().fetchMine(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // My Intent / My Projects, each allocated half the page height
          // (top/bottom, divider between -- same treatment as the Logout
          // divider in Profile), independently scrollable within their half
          // so a long project list doesn't push Intent off-screen. Styled
          // like GitHub Activity / Top Languages: a mono caption heading and
          // plain content, no card border around the whole section.
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _IntentSection(intent: intent),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Palette.ink200, height: 1),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: _ProjectsSection(projects: projects),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BrutalButton(
            label: '＋ New project',
            color: Palette.teal,
            onPressed: () => context.push('/projects/new'),
          ),
          const SizedBox(height: 12),
          // F7: requests inbox + conversations.
          BrutalButton(
            label: 'Requests & messages',
            color: Palette.copper,
            outline: true,
            onPressed: () => context.push('/requests'),
          ),
          const SizedBox(height: 12),
          // F8: the request market.
          BrutalButton(
            label: 'Request market',
            color: Palette.mustard,
            outline: true,
            onPressed: () => context.push('/market'),
          ),
        ],
      ),
    );
  }
}

class _IntentSection extends StatelessWidget {
  const _IntentSection({required this.intent});

  final IntentBadge? intent;

  @override
  Widget build(BuildContext context) {
    final current = intent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MY INTENT',
                style: AppType.mono(
                    size: 11, color: Palette.ink400, weight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/intent'),
              child: Text(current == null ? 'set →' : 'edit →',
                  style: AppType.mono(
                      size: 11, color: Palette.copper, weight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (current == null)
          Text('Let others know what you\'re open to.',
              style: AppType.body(size: 13, color: Palette.ink600, height: 1.3))
        else ...[
          Text(current.label,
              style: AppType.body(
                  size: 14, weight: FontWeight.w700, color: Palette.copper)),
          if (current.note != null && current.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(current.note!,
                style: AppType.body(
                    size: 13, color: Palette.ink600, height: 1.3)),
          ],
        ],
      ],
    );
  }
}

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({required this.projects});

  final ProjectsProvider projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MY PROJECTS (${projects.mine.length})',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (projects.loadingMine && projects.mine.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Palette.ink)),
          )
        else if (projects.mine.isEmpty)
          Text(
            'No projects yet — post your first so people can find you.',
            style: AppType.body(size: 13, color: Palette.ink600, height: 1.3),
          )
        else
          for (var i = 0; i < projects.mine.length; i++) ...[
            if (i > 0) const Divider(color: Palette.ink200, height: 18),
            _ProjectRow(project: projects.mine[i]),
          ],
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});

  final ProjectCard project;

  @override
  Widget build(BuildContext context) {
    // Same data as the Plaza feed, which has always shown the first screenshot
    // (see ProjectListCard) — Home rendered title and stage only, so a card you
    // had just added a screenshot to looked identical to one without.
    final shot =
        project.screenshots.isNotEmpty ? project.screenshots.first.url : null;

    return GestureDetector(
      onTap: () => context.push('/projects/${project.id}'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shot != null) ...[
            _Thumb(url: shot),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.title,
                    style: AppType.body(size: 13, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                    project.isArchived
                        ? '${stageLabel(project.stage)} · archived'
                        : stageLabel(project.stage),
                    style: AppType.mono(size: 10, color: Palette.ink400)),
              ],
            ),
          ),
        ],
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
      width: 44,
      height: 44,
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
            Icon(Icons.image_not_supported, color: Palette.ink400, size: 16),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Profile tab: identity, github, completeness, switch role, logout
// -----------------------------------------------------------------------------

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user, required this.roleColor});

  final User user;
  final Color roleColor;

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    context.go('/onboarding/github');
  }

  Future<void> _switchRole(BuildContext context, String role) async {
    await context.read<AuthProvider>().confirmRole(role);
  }

  /// F2: pick an image and upload it as the profile avatar.
  Future<void> _uploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (file == null || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.uploadAvatar(file);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Avatar updated.'
              : auth.error ?? 'Avatar upload failed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Identity header.
        BrutalCard(
          accent: roleColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _uploadAvatar(context),
                    child: Stack(
                      children: [
                        _Avatar(url: user.avatarUrl),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Palette.teal,
                              border: Border.all(
                                  color: Palette.ink, width: 1.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Icon(Icons.photo_camera,
                                size: 9, color: Palette.paper),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text('@${user.githubLogin}',
                                  style: AppType.display(
                                      size: 22, height: 1.05),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (user.githubConnected &&
                                user.linkedinConnected) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message:
                                    'Verified — GitHub + LinkedIn both connected',
                                child: Icon(Icons.verified,
                                    size: 19, color: Palette.lime),
                              ),
                            ],
                          ],
                        ),
                        if (user.reverifyFlag) ...[
                          const SizedBox(height: 10),
                          const BrutalBadge(
                              label: 'REVERIFY',
                              color: Palette.tomato,
                              textColor: Palette.paper),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Role switch, right beside the identity it belongs to,
                  // instead of a separate section further down the page.
                  BrutalDropdown<String>(
                    value: user.primaryRole,
                    borderColor: roleColor,
                    items: const [
                      ('builder', 'Builder'),
                      ('collaborator', 'Collaborator'),
                      ('founder', 'Founder'),
                    ],
                    onChanged: (role) => _switchRole(context, role),
                  ),
                ],
              ),
              if (user.linkedinHeadline != null &&
                  user.linkedinHeadline!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(user.linkedinHeadline!,
                    style: AppType.body(
                        size: 15,
                        weight: FontWeight.w600,
                        height: 1.3,
                        color: Palette.ink600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CompletenessCard(user: user, accent: roleColor),
        const SizedBox(height: 16),
        if (auth.githubSummary != null) _GithubCard(summary: auth.githubSummary!),
        const SizedBox(height: 24),
        // F6: trust-score breakdown.
        BrutalButton(
          label: 'Trust score',
          color: Palette.lime,
          outline: true,
          onPressed: () => context.push('/users/${user.id}/trust'),
        ),
        const SizedBox(height: 12),
        // F10: verified activity + ownership evidence for this user.
        BrutalButton(
          label: 'Verified activity & evidence',
          color: Palette.mustard,
          outline: true,
          onPressed: () => context.push('/users/${user.id}/evidence'),
        ),
        const SizedBox(height: 12),
        // Intent editor entry.
        BrutalButton(
          label: 'Edit intent',
          color: Palette.copper,
          outline: true,
          onPressed: () => context.push('/intent'),
        ),
        const SizedBox(height: 12),
        // F9: the clearly-labelled simulated capability suite.
        BrutalButton(
          label: 'Simulated suite (demo)',
          color: Palette.tomato,
          outline: true,
          onPressed: () => context.push('/mocked'),
        ),
        const SizedBox(height: 24),
        const Divider(color: Palette.ink200, height: 1),
        const SizedBox(height: 20),
        BrutalButton(
          label: 'Logout',
          color: Palette.tomato,
          outline: true,
          onPressed: () => _logout(context),
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: () => context.push('/dev'),
            child: Text('dev · system check',
                style: AppType.mono(size: 11, color: Palette.ink400)),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom nav
// -----------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final Color accent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Palette.cream100,
        border: Border(top: BorderSide(color: Palette.ink, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _kNavItems.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _kNavItems[i].$1,
                  label: _kNavItems[i].$2,
                  selected: index == i,
                  accent: accent,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Side rail (tablet / desktop / web — width >= kWideLayoutBreakpoint)
// -----------------------------------------------------------------------------

/// The wide-viewport counterpart to [_BottomNav]. Same destinations, same
/// [_NavItem] visual language, just stacked vertically down a fixed-width
/// rail instead of spread across the bottom of the screen.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final Color accent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      decoration: const BoxDecoration(
        color: Palette.cream100,
        border: Border(right: BorderSide(color: Palette.ink, width: 2)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 20),
            for (var i = 0; i < _kNavItems.length; i++)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: _NavItem(
                  icon: _kNavItems[i].$1,
                  label: _kNavItems[i].$2,
                  selected: index == i,
                  accent: accent,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          // A calm tint of the role accent instead of a solid fill + hard
          // shadow -- the nav rail is on-screen permanently, so its selected
          // state shouldn't compete with the one signature stamp reserved
          // for verified evidence elsewhere in the app.
          color: selected
              ? Color.alphaBlend(accent.withValues(alpha: 0.16), Palette.paper)
              : Palette.paper,
          border: Border.all(
              color: selected ? accent : Palette.ink200,
              width: selected ? 1.5 : 1.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? accent : Palette.ink400),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                style: AppType.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: selected ? accent : Palette.ink400)),
          ],
        ),
      ),
    );
  }
}

/// A chunky brutalist progress bar for profile completeness.
class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.user, required this.accent});

  final User user;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final clamped = user.completenessPct.clamp(0, 100);
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PROFILE COMPLETENESS',
                  style: AppType.mono(
                      size: 11,
                      color: Palette.ink400,
                      weight: FontWeight.w700)),
              const Spacer(),
              Text('$clamped%', style: AppType.display(size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: Palette.cream100,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: clamped / 100,
                child: Container(color: accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // What actually makes up the percentage (40 + 40 + 20) -- icons
          // instead of the old GATE 40/70 tick labels, which described
          // discovery/matching thresholds that aren't actually wired up in
          // the backend yet.
          Row(
            children: [
              _CompletenessIcon(
                  icon: Icons.code, label: 'GITHUB', done: user.githubConnected),
              const SizedBox(width: 18),
              _CompletenessIcon(
                  icon: Icons.badge,
                  label: 'LINKEDIN',
                  done: user.linkedinConnected),
              const SizedBox(width: 18),
              _CompletenessIcon(
                  icon: Icons.how_to_reg,
                  label: 'ROLE',
                  done: user.onboardingComplete),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletenessIcon extends StatelessWidget {
  const _CompletenessIcon({
    required this.icon,
    required this.label,
    required this.done,
  });

  final IconData icon;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? Palette.lime : Palette.ink400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: AppType.mono(size: 10, weight: FontWeight.w700, color: color)),
      ],
    );
  }
}

/// The GitHub public-activity summary card.
class _GithubCard extends StatelessWidget {
  const _GithubCard({required this.summary});

  final GithubSummary summary;

  @override
  Widget build(BuildContext context) {
    final topLangs = summary.topLanguages.take(5).toList();
    final totalLangCount = topLangs.fold<int>(0, (sum, l) => sum + l.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GITHUB ACTIVITY',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 14),
        // Bento tiles instead of a borderless divided strip: these four
        // numbers are genuinely heterogeneous metrics (not repeated rows of
        // the same shape), so grouping them as distinct bordered tiles that
        // can be scanned at a glance earns the pattern -- unlike a repeating
        // feed list, where the same treatment would just be noise.
        Row(
          children: [
            Expanded(
                child: _BentoTile(
                    value: '${summary.publicRepos}', label: 'REPOS')),
            const SizedBox(width: 10),
            Expanded(
                child: _BentoTile(
                    value: '${summary.followers}', label: 'FOLLOWERS')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child:
                    _BentoTile(value: '${summary.stars}', label: 'STARS')),
            const SizedBox(width: 10),
            Expanded(
                child: _BentoTile(
                    value: '${summary.recentActivityCount}',
                    label: 'RECENT')),
          ],
        ),
        if (topLangs.isNotEmpty && totalLangCount > 0) ...[
          const SizedBox(height: 22),
          Text('TOP LANGUAGES',
              style: AppType.mono(
                  size: 11, color: Palette.ink400, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          // GitHub's own repo-language-bar pattern: one bar, proportional
          // segments, instead of a badge per language.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < topLangs.length; i++)
                    Expanded(
                      flex: topLangs[i].count > 0 ? topLangs[i].count : 1,
                      child: Container(
                          color: _langColors[i % _langColors.length]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (var i = 0; i < topLangs.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _langColors[i % _langColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(topLangs[i].language,
                        style: AppType.mono(size: 12, color: Palette.ink600)),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A single bento-grid metric tile: hairline border + soft shadow, same
/// elevation language as [BrutalCard]'s default (non-signature) treatment.
class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.paper,
        border: Border.all(color: Palette.ink200, width: 1.25),
        borderRadius: BorderRadius.circular(8),
        boxShadow: Palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.mono(
                  size: 9, color: Palette.ink400, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: AppType.display(size: 20)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Palette.cream100,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person, size: 18, color: Palette.ink400)
          : Image.network(url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person, color: Palette.ink400)),
    );
  }
}
