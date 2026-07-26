import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/github_summary.dart';
import '../../models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';
import '../../widgets/project_list_card.dart';
import '../login_screen.dart' show kRoleColors;
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

    // Resolve the default tab once the user (and role) is known.
    final index = _index ??=
        (user != null && user.primaryRole == 'builder') ? 0 : 1;

    if (user == null) {
      return const BrutalScaffold(
        title: 'Home',
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
          // Intent card.
          BrutalCard(
            accent: Palette.copper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('MY INTENT',
                        style: AppType.mono(
                            size: 11,
                            color: Palette.ink400,
                            weight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/intent'),
                      child: Text(intent == null ? 'set →' : 'edit →',
                          style: AppType.mono(
                              size: 12,
                              color: Palette.copper,
                              weight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (intent == null)
                  Text('Let others know what you\'re open to.',
                      style: AppType.body(size: 14, color: Palette.ink600))
                else ...[
                  BrutalBadge(
                      label: intent.label,
                      color: Palette.copper,
                      textColor: Palette.paper),
                  if (intent.note != null && intent.note!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(intent.note!,
                        style:
                            AppType.body(size: 14, color: Palette.ink600)),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Text('MY PROJECTS',
                  style: AppType.display(size: 20)),
              const Spacer(),
              Text('${projects.mine.length}',
                  style: AppType.display(size: 20, color: Palette.ink400)),
            ],
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: '＋ New project',
            color: Palette.teal,
            onPressed: () => context.push('/projects/new'),
          ),
          const SizedBox(height: 16),
          if (projects.loadingMine && projects.mine.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                  child: CircularProgressIndicator(color: Palette.ink)),
            )
          else if (projects.mine.isEmpty)
            BrutalCard(
              background: Palette.cream100,
              child: Text(
                'No projects yet. Post your first one so founders and '
                'collaborators can find you.',
                style: AppType.body(size: 14, color: Palette.ink600),
              ),
            )
          else
            for (final project in projects.mine) ...[
              ProjectListCard(
                project: project,
                showOwner: false,
                onTap: () => context.push('/projects/${project.id}'),
              ),
              const SizedBox(height: 14),
            ],
        ],
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
        Text('SWITCH ROLE',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kRoleColors.entries)
              BrutalBadge(
                label: entry.key,
                color: entry.value,
                selected: user.primaryRole == entry.key,
                onTap: user.primaryRole == entry.key
                    ? null
                    : () => _switchRole(context, entry.key),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            GestureDetector(
              onTap: () => _logout(context),
              child: Text('Logout',
                  style: AppType.mono(
                      size: 13, color: Palette.tomato, weight: FontWeight.w700)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/dev'),
              child: Text('dev · system check',
                  style: AppType.mono(size: 11, color: Palette.ink400)),
            ),
          ],
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
          color: selected ? accent : Palette.paper,
          border: Border.all(color: Palette.ink, width: 2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: Palette.ink, offset: Offset(2, 2), blurRadius: 0),
                ]
              : const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? (accent == Palette.teal || accent == Palette.copper
                        ? Palette.paper
                        : Palette.ink)
                    : Palette.ink400),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                style: AppType.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: selected
                        ? (accent == Palette.teal || accent == Palette.copper
                            ? Palette.paper
                            : Palette.ink)
                        : Palette.ink400)),
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
        // A borderless stat strip instead of another bordered card full of
        // badges -- four numbers separated by hairline dividers, like a
        // scoreboard rather than a pile of boxed tags.
        Row(
          children: [
            _Stat(value: '${summary.publicRepos}', label: 'REPOS'),
            const _StatDivider(),
            _Stat(value: '${summary.followers}', label: 'FOLLOWERS'),
            const _StatDivider(),
            _Stat(value: '${summary.stars}', label: 'STARS'),
            const _StatDivider(),
            _Stat(value: '${summary.recentActivityCount}', label: 'RECENT'),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppType.display(size: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: AppType.mono(
                  size: 9, color: Palette.ink400, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1.5, height: 32, color: Palette.ink200);
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
