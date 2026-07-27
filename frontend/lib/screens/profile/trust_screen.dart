import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../models/trust_score.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';

/// F6: the trust-score breakdown for one user — total, per-component bars
/// (with weights and availability), peer reviews, and the clearly-labelled
/// simulated Stripe badge.
class TrustScreen extends StatefulWidget {
  const TrustScreen({super.key, required this.userId});

  final String userId;

  @override
  State<TrustScreen> createState() => _TrustScreenState();
}

class _TrustScreenState extends State<TrustScreen> {
  TrustScore? _score;
  List<PeerReviewItem>? _reviews;
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
        dio.get<Map<String, dynamic>>('/users/${widget.userId}/trust-score'),
        dio.get<List<dynamic>>('/users/${widget.userId}/reviews'),
      ]);
      if (!mounted) return;
      setState(() {
        _score = TrustScore.fromJson(
            (results[0] as dynamic).data as Map<String, dynamic>);
        _reviews = ((results[1] as dynamic).data as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PeerReviewItem.fromJson)
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrutalScaffold(
      title: 'Trust Score',
      titleBarColor: Palette.lime,
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
          : _score == null
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
    final score = _score!;
    final reviews = _reviews ?? const <PeerReviewItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Total.
        BrutalCard(
          accent: Palette.lime,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${score.githubLogin}',
                        style: AppType.display(size: 22, height: 1.05),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('Blend of verified sources, weights shown below.',
                        style:
                            AppType.body(size: 13, color: Palette.ink600)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Palette.lime,
                  border: Border.all(color: Palette.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                        color: Palette.ink,
                        offset: Offset(3, 3),
                        blurRadius: 0),
                  ],
                ),
                child: Text(score.total.toStringAsFixed(0),
                    style: AppType.display(size: 34)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('COMPONENTS',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (var i = 0; i < score.components.length; i++) ...[
          if (i > 0) const Divider(color: Palette.ink200, height: 22),
          _ComponentRow(component: score.components[i]),
        ],
        const SizedBox(height: 20),
        BrutalButton(
          label: 'View verified activity & evidence',
          color: Palette.mustard,
          outline: true,
          onPressed: () => context.push('/users/${widget.userId}/evidence'),
        ),
        const SizedBox(height: 24),
        Text('PEER REVIEWS',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          BrutalCard(
            background: Palette.cream100,
            child: Text(
              'No peer reviews yet. Reviews unlock after a collaboration '
              'request is accepted.',
              style: AppType.body(size: 14, color: Palette.ink600),
            ),
          )
        else
          for (var i = 0; i < reviews.length; i++) ...[
            if (i > 0) const Divider(color: Palette.ink200, height: 22),
            _ReviewRow(review: reviews[i]),
          ],
      ],
    );
  }
}

/// A trust component's label/score/bar/detail, borderless -- same idea as
/// the Top Languages bar in Profile: one bordered progress bar carries the
/// visual weight, everything around it is plain text.
class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final TrustComponent component;

  @override
  Widget build(BuildContext context) {
    final score = component.score;
    final pct = ((score ?? 0) / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(component.label.toUpperCase(),
                style: AppType.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color:
                        component.available ? Palette.ink : Palette.ink400)),
            const SizedBox(width: 8),
            if (component.simulated)
              const BrutalBadge(
                  label: 'SIMULATED',
                  color: Palette.tomato,
                  textColor: Palette.paper),
            const Spacer(),
            Text(
                score == null
                    ? '—'
                    : '${score.toStringAsFixed(0)} · w ${(component.weight * 100).toStringAsFixed(0)}%',
                style: AppType.mono(size: 12, color: Palette.ink600)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Palette.cream100,
            border: Border.all(color: Palette.ink, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                  color: component.available ? Palette.teal : Palette.ink200),
            ),
          ),
        ),
        if (component.detail != null) ...[
          const SizedBox(height: 6),
          Text(component.detail!,
              style:
                  AppType.body(size: 12, color: Palette.ink600, height: 1.3)),
        ],
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final PeerReviewItem review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('@${review.reviewerLogin}',
                style: AppType.mono(size: 13, weight: FontWeight.w700)),
            const Spacer(),
            Text('★' * review.stars + '☆' * (5 - review.stars),
                style: AppType.body(size: 15, color: Palette.mustard)),
          ],
        ),
        if (review.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(review.tags.join(', '),
              style: AppType.mono(size: 11, color: Palette.ink600)),
        ],
      ],
    );
  }
}
