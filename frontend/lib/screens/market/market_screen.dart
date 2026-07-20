import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../login_screen.dart' show kRoleColors;

/// F8: the unified Request Market — maintainer postings and team-role
/// recruitments in one feed, filterable by type and skill. Applying reuses
/// the F7 structured-request pipeline (context_ref = posting id).
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _skillController = TextEditingController();
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    return context.read<MarketProvider>().fetchPostings(
          postingType: _typeFilter,
          skill: _skillController.text.trim().isEmpty
              ? null
              : _skillController.text.trim(),
        );
  }

  void _toggleType(String type) {
    setState(() => _typeFilter = _typeFilter == type ? null : type);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    final myId = context.watch<AuthProvider>().currentUser?.id;

    return BrutalScaffold(
      title: 'Request Market',
      titleBarColor: Palette.mustard,
      body: RefreshIndicator(
        color: Palette.ink,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BrutalButton(
              label: '＋ Post a role',
              color: Palette.cobalt,
              onPressed: () => context.push('/market/new'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                BrutalBadge(
                  label: 'MAINTAINER',
                  color: Palette.lime,
                  selected: _typeFilter == 'maintainer',
                  onTap: () => _toggleType('maintainer'),
                ),
                const SizedBox(width: 8),
                BrutalBadge(
                  label: 'TEAM ROLE',
                  color: Palette.mustard,
                  selected: _typeFilter == 'team_role',
                  onTap: () => _toggleType('team_role'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skillController,
              style: AppType.body(size: 15, weight: FontWeight.w500),
              cursorColor: Palette.cobalt,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: 'Filter by skill (e.g. Flutter)…',
                hintStyle: AppType.body(size: 15, color: Palette.ink400),
                prefixIcon: Icon(Icons.search, color: Palette.ink400),
                filled: true,
                fillColor: Palette.paper,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: Palette.ink, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: Palette.cobalt, width: 2.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (provider.loading && provider.postings.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                    child:
                        CircularProgressIndicator(color: Palette.ink)),
              )
            else if (provider.postings.isEmpty)
              BrutalCard(
                background: Palette.cream100,
                child: Text(
                  provider.error ??
                      'No open postings match. Post the first one.',
                  style: AppType.body(size: 14, color: Palette.ink600),
                ),
              )
            else
              for (final posting in provider.postings) ...[
                _PostingCard(posting: posting, myId: myId),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _PostingCard extends StatelessWidget {
  const _PostingCard({required this.posting, required this.myId});

  final RolePosting posting;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final typeColor =
        posting.isMaintainer ? Palette.lime : Palette.mustard;
    final roleColor =
        kRoleColors[posting.owner.primaryRole] ?? Palette.cobalt;
    final isMine = posting.owner.id == myId;

    return BrutalCard(
      accent: typeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrutalBadge(
                  label: posting.isMaintainer
                      ? 'MAINTAINER'
                      : 'TEAM ROLE',
                  color: typeColor),
              const Spacer(),
              Text('@${posting.owner.githubLogin}',
                  style: AppType.mono(
                      size: 12,
                      weight: FontWeight.w700,
                      color: Palette.ink600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(posting.roleDesc,
              style: AppType.body(size: 14, height: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (posting.projectTitle != null)
                BrutalBadge(
                    label: posting.projectTitle!,
                    color: Palette.cobalt,
                    textColor: Palette.paper),
              if (posting.accessTier != null)
                BrutalBadge(
                    label: kAccessTierLabels[posting.accessTier!] ??
                        posting.accessTier!,
                    color: Palette.lime),
              if (posting.stage != null)
                BrutalBadge(label: posting.stage!, color: Palette.paper),
              if (posting.techStack != null)
                BrutalBadge(
                    label: posting.techStack!, color: Palette.paper),
              if (posting.commitment != null)
                BrutalBadge(
                    label: posting.commitment!, color: Palette.paper),
              for (final skill in posting.skills.take(4))
                BrutalBadge(
                    label: skill,
                    color: Palette.cream100,
                    textColor: Palette.ink),
              BrutalBadge(
                label: posting.owner.primaryRole,
                color: roleColor,
                textColor: roleColor == Palette.cobalt ||
                        roleColor == Palette.plum
                    ? Palette.paper
                    : Palette.ink,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BrutalButton(
                  label: 'Details',
                  color: Palette.cream100,
                  textColor: Palette.ink,
                  onPressed: () =>
                      context.push('/market/${posting.id}'),
                ),
              ),
              const SizedBox(width: 10),
              if (isMine)
                Expanded(
                  child: BrutalButton(
                    label: 'Close',
                    color: Palette.tomato,
                    onPressed: () => context
                        .read<MarketProvider>()
                        .closePosting(posting.id),
                  ),
                )
              else
                Expanded(
                  child: BrutalButton(
                    label: 'Apply',
                    color: Palette.plum,
                    onPressed: () => showRequestFormSheet(
                      context,
                      toUserId: posting.owner.id,
                      toUserLogin: posting.owner.githubLogin,
                      contextRef: posting.id,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
