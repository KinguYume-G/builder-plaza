import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/role_posting.dart';
import '../../state/auth_provider.dart';
import '../../state/market_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';
import '../../widgets/request_form_sheet.dart';

/// F8: one posting in full, including REAL GitHub activity for the linked
/// repos on maintainer postings. Apply = F7 structured request.
class PostingDetailScreen extends StatefulWidget {
  const PostingDetailScreen({super.key, required this.postingId});

  final String postingId;

  @override
  State<PostingDetailScreen> createState() => _PostingDetailScreenState();
}

class _PostingDetailScreenState extends State<PostingDetailScreen> {
  RolePosting? _posting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posting =
          await context.read<MarketProvider>().fetchOne(widget.postingId);
      if (mounted) setState(() => _posting = posting);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this posting.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final posting = _posting;
    final myId = context.watch<AuthProvider>().currentUser?.id;

    return BrutalScaffold(
      title: 'Posting',
      titleBarColor: Palette.mustard,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BrutalCard(
                  accent: Palette.tomato,
                  child: Text(_error!,
                      style:
                          AppType.body(size: 15, color: Palette.tomato)),
                ),
              ),
            )
          : posting == null
              ? const Center(
                  child: CircularProgressIndicator(color: Palette.ink))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _body(posting, myId),
                    ),
                  ),
                ),
    );
  }

  Widget _body(RolePosting posting, String? myId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BrutalBadge(
                label:
                    posting.isMaintainer ? 'MAINTAINER' : 'TEAM ROLE',
                color: posting.isMaintainer
                    ? Palette.lime
                    : Palette.mustard),
            BrutalBadge(
                label: posting.status.toUpperCase(),
                color: posting.status == 'open'
                    ? Palette.lime
                    : Palette.ink200),
            if (posting.accessTier != null)
              BrutalBadge(
                  label: kAccessTierLabels[posting.accessTier!] ??
                      posting.accessTier!,
                  color: Palette.paper),
          ],
        ),
        const SizedBox(height: 16),
        Text(posting.roleDesc,
            style: AppType.body(size: 15, height: 1.4)),
        const SizedBox(height: 16),
        BrutalCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POSTED BY',
                  style: AppType.mono(
                      size: 10,
                      color: Palette.ink400,
                      weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('@${posting.owner.githubLogin}',
                      style: AppType.display(size: 18)),
                  const Spacer(),
                  BrutalBadge(
                      label: posting.owner.primaryRole,
                      color: Palette.cobalt,
                      textColor: Palette.paper),
                ],
              ),
            ],
          ),
        ),
        if (posting.stage != null ||
            posting.techStack != null ||
            posting.commitment != null) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (posting.stage != null)
                BrutalBadge(
                    label: 'stage: ${posting.stage!}',
                    color: Palette.paper),
              if (posting.techStack != null)
                BrutalBadge(
                    label: posting.techStack!, color: Palette.paper),
              if (posting.commitment != null)
                BrutalBadge(
                    label: posting.commitment!, color: Palette.paper),
            ],
          ),
        ],
        if (posting.skills.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in posting.skills)
                BrutalBadge(
                    label: skill,
                    color: Palette.cream100,
                    textColor: Palette.ink),
            ],
          ),
        ],
        if (posting.repos.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('REPOSITORY ACTIVITY',
              style: AppType.mono(
                  size: 11,
                  color: Palette.ink400,
                  weight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final repo in posting.repos) ...[
            BrutalCard(
              padding: const EdgeInsets.all(12),
              accent:
                  repo.error == null ? Palette.cobalt : Palette.ink400,
              child: Row(
                children: [
                  Expanded(
                    child: Text(repo.repo,
                        style: AppType.mono(
                            size: 13, weight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (repo.error != null)
                    Text('unavailable',
                        style: AppType.mono(
                            size: 11, color: Palette.ink400))
                  else ...[
                    BrutalBadge(
                        label: '★ ${repo.stars}',
                        color: Palette.mustard),
                    if (repo.language != null) ...[
                      const SizedBox(width: 8),
                      BrutalBadge(
                          label: repo.language!,
                          color: Palette.paper),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 20),
        if (posting.owner.id != myId && posting.status == 'open')
          BrutalButton(
            label: 'Apply for this role',
            color: Palette.plum,
            onPressed: () => showRequestFormSheet(
              context,
              toUserId: posting.owner.id,
              toUserLogin: posting.owner.githubLogin,
              contextRef: posting.id,
            ),
          ),
      ],
    );
  }
}
