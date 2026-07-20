import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../state/matches_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../login_screen.dart' show kRoleColors;

/// F5: the match round. Every card carries the Match Reason; exploratory
/// picks are labelled EXPLORE; pull-to-refresh re-runs the engine so the
/// exploration slot can change. Scaffold-less so HomeShell embeds it as a tab.
class MatchesBody extends StatefulWidget {
  const MatchesBody({super.key});

  @override
  State<MatchesBody> createState() => _MatchesBodyState();
}

class _MatchesBodyState extends State<MatchesBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<MatchesProvider>().fetchMatches());
  }

  Future<void> _showCredibility(BuildContext context, MatchCandidate candidate) async {
    final provider = context.read<MatchesProvider>();
    CredibilitySummary? summary;
    try {
      summary = await provider.fetchCredibility(candidate.id);
    } catch (_) {
      summary = null;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CredibilitySheet(
        candidate: candidate,
        summary: summary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MatchesProvider>();

    return RefreshIndicator(
      color: Palette.ink,
      onRefresh: () => context.read<MatchesProvider>().fetchMatches(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Matched on verified skills — pull to refresh for a new round '
            '(the exploration slot changes).',
            style: AppType.body(size: 13, color: Palette.ink600),
          ),
          const SizedBox(height: 16),
          if (provider.loading && provider.matches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child:
                  Center(child: CircularProgressIndicator(color: Palette.ink)),
            )
          else if (provider.matches.isEmpty)
            BrutalCard(
              background: Palette.cream100,
              child: Text(
                provider.error ??
                    'No matches yet. Matches appear as more verified builders '
                        'join the plaza.',
                style: AppType.body(size: 14, color: Palette.ink600),
              ),
            )
          else
            for (final match in provider.matches) ...[
              _MatchCard(
                match: match,
                onTapCandidate: () =>
                    _showCredibility(context, match.candidate),
                onDismiss: () =>
                    context.read<MatchesProvider>().dismiss(match.id),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onTapCandidate,
    required this.onDismiss,
  });

  final MatchItem match;
  final VoidCallback onTapCandidate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final candidate = match.candidate;
    final roleColor = kRoleColors[candidate.primaryRole] ?? Palette.cobalt;

    return BrutalCard(
      accent: match.exploratory ? Palette.mustard : roleColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onTapCandidate,
                child: Text('@${candidate.githubLogin}',
                    style: AppType.display(size: 19, height: 1.05)),
              ),
              const Spacer(),
              Text('${(match.score * 100).toStringAsFixed(0)}%',
                  style: AppType.display(size: 19, color: Palette.ink600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalBadge(
                label: candidate.primaryRole,
                color: roleColor,
                textColor:
                    roleColor == Palette.cobalt || roleColor == Palette.plum
                        ? Palette.paper
                        : Palette.ink,
              ),
              BrutalBadge(
                  label: 'trust ${candidate.trustScore.toStringAsFixed(0)}',
                  color: Palette.lime),
              if (match.exploratory)
                const BrutalBadge(label: 'EXPLORE', color: Palette.mustard),
            ],
          ),
          if (candidate.headline != null &&
              candidate.headline!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(candidate.headline!,
                style: AppType.body(
                    size: 13,
                    color: Palette.ink600,
                    weight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Palette.cream100,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHY ',
                    style: AppType.mono(
                        size: 10,
                        weight: FontWeight.w700,
                        color: Palette.ink400)),
                Expanded(
                  child: Text(match.matchReason,
                      style: AppType.body(size: 13, height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BrutalButton(
                  label: 'Credibility',
                  color: Palette.cobalt,
                  onPressed: onTapCandidate,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Palette.paper,
                    border: Border.all(color: Palette.ink, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Dismiss',
                      style: AppType.mono(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Palette.tomato)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: the plain-language credibility summary + evidence links.
class _CredibilitySheet extends StatelessWidget {
  const _CredibilitySheet({required this.candidate, required this.summary});

  final MatchCandidate candidate;
  final CredibilitySummary? summary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BrutalCard(
          accent: Palette.cobalt,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('@${candidate.githubLogin}',
                  style: AppType.display(size: 22)),
              const SizedBox(height: 10),
              Text(
                summary?.summary ?? 'Credibility summary unavailable.',
                style: AppType.body(size: 14, height: 1.4),
              ),
              if (summary != null && summary!.highlights.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final highlight in summary!.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('■ ',
                            style: AppType.mono(
                                size: 12, color: Palette.cobalt)),
                        Expanded(
                          child: Text(highlight,
                              style: AppType.body(size: 13, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              BrutalButton(
                label: 'Trust score',
                color: Palette.lime,
                textColor: Palette.ink,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/users/${candidate.id}/trust');
                },
              ),
              const SizedBox(height: 10),
              BrutalButton(
                label: 'Verified activity & evidence',
                color: Palette.mustard,
                textColor: Palette.ink,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/users/${candidate.id}/evidence');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
