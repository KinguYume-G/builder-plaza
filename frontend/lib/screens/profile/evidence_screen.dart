import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/activity.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';

/// F10: Verified Activity timeline + Ownership Evidence for one user.
///
/// Everything shown here comes from GitHub's public record for the connected
/// account (nothing self-reported): the recent event timeline, a 12-week
/// activity continuity chart, and the roles held on each repository.
class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key, required this.userId});

  final String userId;

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  ActivityTimeline? _timeline;
  OwnershipEvidence? _evidence;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dio = ApiClient.instance.dio;
    try {
      final results = await Future.wait([
        dio.get<Map<String, dynamic>>(
            '/users/${widget.userId}/activity-timeline'),
        dio.get<Map<String, dynamic>>(
            '/users/${widget.userId}/ownership-evidence'),
      ]);
      if (!mounted) return;
      setState(() {
        _timeline = ActivityTimeline.fromJson(results[0].data!);
        _evidence = OwnershipEvidence.fromJson(results[1].data!);
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrutalScaffold(
      title: 'Evidence',
      titleBarColor: Palette.mustard,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BrutalCard(
                  accent: Palette.tomato,
                  child: Text(_error!,
                      style: AppType.body(size: 15, color: Palette.tomato)),
                ),
              ),
            )
          : _timeline == null || _evidence == null
              ? const Center(
                  child: CircularProgressIndicator(color: Palette.ink))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _body(),
                    ),
                  ),
                ),
    );
  }

  Widget _body() {
    final timeline = _timeline!;
    final evidence = _evidence!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('@${timeline.githubLogin}',
            style: AppType.display(size: 26, height: 1.05)),
        const SizedBox(height: 6),
        Text(
          'Everything below comes from the public GitHub record',
          style: AppType.body(size: 13, color: Palette.ink600),
        ),
        const SizedBox(height: 20),

        // --- Ownership Evidence: continuity chart ---
        // The one certified/verified block on this screen (public GitHub
        // record, not self-reported) -- keeps the signature hard-shadow.
        BrutalCard(
          accent: Palette.mustard,
          signature: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('ACTIVITY CONTINUITY',
                      style: AppType.mono(
                          size: 11,
                          color: Palette.ink400,
                          weight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                      '${evidence.activeWeeks}/${evidence.totalWeeks} weeks',
                      style: AppType.display(size: 16)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 140, child: _ContinuityChart(evidence)),
              const SizedBox(height: 6),
              Text('last ${evidence.totalWeeks} weeks · public events',
                  style: AppType.mono(size: 10, color: Palette.ink400)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Ownership Evidence: repo roles ---
        if (evidence.repoRoles.isNotEmpty) ...[
          Text('REPOSITORY ROLES',
              style: AppType.mono(
                  size: 11, color: Palette.ink400, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final role in evidence.repoRoles.take(6)) ...[
            BrutalCard(
              flat: true,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(role.repo,
                        style:
                            AppType.mono(size: 13, weight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  BrutalBadge(
                    label: role.role == 'owner' ? 'OWNER' : 'FORK',
                    color: role.role == 'owner'
                        ? Palette.lime
                        : Palette.cream100,
                  ),
                  if (role.stars > 0) ...[
                    const SizedBox(width: 8),
                    BrutalBadge(
                        label: '★ ${role.stars}', color: Palette.mustard),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],

        // --- Verified Activity timeline ---
        Text('VERIFIED ACTIVITY',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (timeline.events.isEmpty)
          BrutalCard(
            background: Palette.cream100,
            child: Text('No recent public GitHub activity.',
                style: AppType.body(size: 14, color: Palette.ink600)),
          )
        else
          for (final event in timeline.events.take(30)) ...[
            _TimelineTile(event: event),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ContinuityChart extends StatelessWidget {
  const _ContinuityChart(this.evidence);

  final OwnershipEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final weeks = evidence.weeklyActivity;
    final maxCount = weeks.fold<int>(0, (max, w) => w.count > max ? w.count : max);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: (maxCount == 0 ? 1 : maxCount).toDouble() * 1.2,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Palette.ink, width: 2),
          ),
        ),
        barTouchData: BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < weeks.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weeks[i].count.toDouble(),
                  width: 14,
                  borderRadius: BorderRadius.circular(2),
                  color: weeks[i].count > 0 ? Palette.teal : Palette.ink200,
                  borderSide: weeks[i].count > 0
                      ? const BorderSide(color: Palette.ink, width: 1.5)
                      : BorderSide.none,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final ActivityEvent event;

  IconData get _icon => switch (event.type) {
        'PushEvent' => Icons.commit,
        'PullRequestEvent' => Icons.merge_type,
        'CreateEvent' => Icons.fork_right,
        'ReleaseEvent' => Icons.rocket_launch,
        'IssuesEvent' => Icons.error_outline,
        _ => Icons.circle,
      };

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      flat: true,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Palette.cream100,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_icon, size: 18, color: Palette.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BrutalBadge(
                        label: event.typeLabel,
                        color: Palette.paper,
                        textColor: Palette.ink),
                    const Spacer(),
                    if (event.createdAt != null)
                      Text(_ago(event.createdAt!),
                          style:
                              AppType.mono(size: 10, color: Palette.ink400)),
                  ],
                ),
                const SizedBox(height: 6),
                if (event.repo != null)
                  Text(event.repo!,
                      style: AppType.mono(
                          size: 12, weight: FontWeight.w700,
                          color: Palette.ink600)),
                if (event.detail != null && event.detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(event.detail!,
                      style: AppType.body(
                          size: 13, color: Palette.ink600, height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when.toLocal());
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
