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
    final meta = [
      if (posting.stage != null) posting.stage!,
      if (posting.techStack != null) posting.techStack!,
      if (posting.commitment != null) posting.commitment!,
      if (posting.accessTier != null)
        kAccessTierLabels[posting.accessTier!] ?? posting.accessTier!,
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(posting.isMaintainer ? Icons.build : Icons.groups,
                size: 15, color: Palette.ink600),
            const SizedBox(width: 6),
            Text(posting.isMaintainer ? 'Maintainer' : 'Team role',
                style: AppType.mono(
                    size: 11, weight: FontWeight.w700, color: Palette.ink600)),
            const SizedBox(width: 14),
            BrutalBadge(
                label: posting.status.toUpperCase(),
                color: posting.status == 'open'
                    ? Palette.lime
                    : Palette.ink200),
          ],
        ),
        const SizedBox(height: 16),
        Text(posting.roleDesc,
            style: AppType.body(size: 15, height: 1.4)),
        const SizedBox(height: 16),
        // Identity as a plain row, not a bordered box -- the person isn't
        // the point of this screen, the role is.
        Row(
          children: [
            _OwnerAvatar(url: posting.owner.avatarUrl),
            const SizedBox(width: 10),
            Text('@${posting.owner.githubLogin}',
                style: AppType.display(size: 17)),
            const SizedBox(width: 8),
            Text(posting.owner.primaryRole,
                style: AppType.mono(size: 11, color: Palette.ink400)),
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(meta,
              style: AppType.mono(size: 12, color: Palette.ink600)),
        ],
        if (posting.skills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(posting.skills.join(', '),
              style: AppType.body(size: 13, color: Palette.ink600)),
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
              flat: true,
              padding: const EdgeInsets.all(12),
              accent:
                  repo.error == null ? Palette.teal : Palette.ink400,
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
            color: Palette.copper,
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

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Palette.cream100,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person, size: 16, color: Palette.ink400)
          : Image.network(url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person, size: 16, color: Palette.ink400)),
    );
  }
}
