import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/collab.dart';
import '../../state/collab_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';

/// F7: requests inbox/sent + open conversations. Accepting a request opens
/// the conversation — the only way a DM channel comes to exist.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  /// 0 = inbox, 1 = sent, 2 = conversations
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<CollabProvider>().fetchAll());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollabProvider>();

    return BrutalScaffold(
      title: 'Requests',
      titleBarColor: Palette.copper,
      body: RefreshIndicator(
        color: Palette.ink,
        onRefresh: () => context.read<CollabProvider>().fetchAll(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                BrutalBadge(
                  label: 'INBOX (${provider.pendingInboxCount})',
                  color: Palette.copper,
                  textColor:
                      _tab == 0 ? Palette.paper : Palette.ink,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                BrutalBadge(
                  label: 'SENT',
                  color: Palette.copper,
                  textColor: _tab == 1 ? Palette.paper : Palette.ink,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const SizedBox(width: 8),
                BrutalBadge(
                  label: 'CHATS (${provider.conversations.length})',
                  color: Palette.teal,
                  textColor: _tab == 2 ? Palette.paper : Palette.ink,
                  selected: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (provider.loading &&
                provider.inbox.isEmpty &&
                provider.sent.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                    child: CircularProgressIndicator(color: Palette.ink)),
              )
            else if (_tab == 2)
              ..._conversationTiles(provider)
            else
              ..._requestTiles(provider),
          ],
        ),
      ),
    );
  }

  List<Widget> _conversationTiles(CollabProvider provider) {
    if (provider.conversations.isEmpty) {
      return [
        BrutalCard(
          background: Palette.cream100,
          child: Text(
            'No conversations yet. Accept a request (or have yours accepted) '
            'to open one.',
            style: AppType.body(size: 14, color: Palette.ink600),
          ),
        ),
      ];
    }
    return [
      for (final conversation in provider.conversations) ...[
        BrutalCard(
          flat: true,
          accent: Palette.teal,
          padding: const EdgeInsets.all(14),
          child: InkWell(
            onTap: () => context.push('/conversations/${conversation.id}',
                extra: conversation.counterpart.githubLogin),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${conversation.counterpart.githubLogin}',
                          style: AppType.display(size: 17)),
                      const SizedBox(height: 6),
                      Text(
                        conversation.lastMessage?.body ??
                            'Conversation open — say hi.',
                        style:
                            AppType.body(size: 13, color: Palette.ink600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Palette.ink400),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _requestTiles(CollabProvider provider) {
    final requests = _tab == 0 ? provider.inbox : provider.sent;
    if (requests.isEmpty) {
      return [
        BrutalCard(
          background: Palette.cream100,
          child: Text(
            _tab == 0
                ? 'No incoming requests yet.'
                : 'You have not sent any requests. Find people in Matches.',
            style: AppType.body(size: 14, color: Palette.ink600),
          ),
        ),
      ];
    }
    return [
      for (final request in requests) ...[
        _RequestCard(request: request, isInbox: _tab == 0),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isInbox,
  });

  final CollabRequestItem request;
  final bool isInbox;

  Color get _stateColor => switch (request.state) {
        'pending' => Palette.mustard,
        'accepted' => Palette.lime,
        'declined' => Palette.tomato,
        _ => Palette.ink200,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CollabProvider>();
    final other = isInbox ? request.fromUser : request.toUser;

    return BrutalCard(
      flat: true,
      accent: _stateColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('@${other.githubLogin}',
                    style: AppType.display(size: 17),
                    overflow: TextOverflow.ellipsis),
              ),
              BrutalBadge(
                label: request.state.toUpperCase(),
                color: _stateColor,
                textColor: request.state == 'declined'
                    ? Palette.paper
                    : Palette.ink,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              BrutalBadge(
                  label: request.intentLabel,
                  color: Palette.copper,
                  textColor: Palette.paper),
              BrutalBadge(label: other.primaryRole, color: Palette.paper),
            ],
          ),
          const SizedBox(height: 10),
          Text(request.pitch,
              style: AppType.body(size: 14, height: 1.35)),
          const SizedBox(height: 12),
          if (isInbox && request.state == 'pending')
            Row(
              children: [
                Expanded(
                  child: BrutalButton(
                    label: 'Accept',
                    color: Palette.lime,
                    textColor: Palette.ink,
                    onPressed: () async {
                      final updated = await provider.accept(request.id);
                      if (updated?.conversationId != null &&
                          context.mounted) {
                        context.push(
                            '/conversations/${updated!.conversationId}',
                            extra: other.githubLogin);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrutalButton(
                    label: 'Decline',
                    color: Palette.tomato,
                    onPressed: () => provider.decline(request.id),
                  ),
                ),
              ],
            )
          else if (!isInbox && request.state == 'pending')
            BrutalButton(
              label: 'Withdraw',
              color: Palette.cream100,
              textColor: Palette.tomato,
              onPressed: () => provider.withdraw(request.id),
            )
          else if (request.state == 'accepted' &&
              request.conversationId != null)
            BrutalButton(
              label: 'Open conversation',
              color: Palette.teal,
              onPressed: () => context.push(
                  '/conversations/${request.conversationId}',
                  extra: other.githubLogin),
            ),
        ],
      ),
    );
  }
}
