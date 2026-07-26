import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/collab.dart';
import '../../state/auth_provider.dart';
import '../../state/collab_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_scaffold.dart';

/// F7: one conversation. Messages poll every 10 seconds (incremental via the
/// last-seen message id) — no websockets needed at this scale.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.counterpartLogin,
  });

  final String conversationId;
  final String? counterpartLogin;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageItem> _messages = const [];
  Timer? _pollTimer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final messages = await context
          .read<CollabProvider>()
          .fetchMessages(widget.conversationId);
      if (!mounted) return;
      setState(() => _messages = messages);
      _jumpToEnd();
    } catch (_) {
      // Leave the empty state; the poll will retry.
    }
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final afterId = _messages.isEmpty ? null : _messages.last.id;
      final fresh = await context
          .read<CollabProvider>()
          .fetchMessages(widget.conversationId, afterId: afterId);
      if (!mounted || fresh.isEmpty) return;
      setState(() => _messages = [..._messages, ...fresh]);
      _jumpToEnd();
    } catch (_) {
      // Transient poll failure: try again next tick.
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final message = await context
        .read<CollabProvider>()
        .sendMessage(widget.conversationId, body);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (message != null) {
        _messages = [..._messages, message];
        _controller.clear();
      }
    });
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController
            .jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser?.id;

    return BrutalScaffold(
      title: widget.counterpartLogin != null
          ? '@${widget.counterpartLogin}'
          : 'Conversation',
      titleBarColor: Palette.teal,
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('No messages yet — say hi.',
                        style: AppType.body(
                            size: 14, color: Palette.ink400)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message.senderId == myId;
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints:
                              const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Palette.teal
                                : Palette.paper,
                            border: Border.all(
                                color: Palette.ink, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                  color: Palette.ink,
                                  offset: Offset(2, 2),
                                  blurRadius: 0),
                            ],
                          ),
                          child: Text(
                            message.body,
                            style: AppType.body(
                              size: 14,
                              height: 1.35,
                              color: isMine
                                  ? Palette.paper
                                  : Palette.ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Palette.cream100,
              border:
                  Border(top: BorderSide(color: Palette.ink, width: 2)),
            ),
            padding: const EdgeInsets.all(12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppType.body(size: 14),
                      cursorColor: Palette.teal,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        hintStyle: AppType.body(
                            size: 14, color: Palette.ink400),
                        filled: true,
                        fillColor: Palette.paper,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: Palette.ink, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: Palette.teal, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Palette.teal,
                        border:
                            Border.all(color: Palette.ink, width: 2),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                              color: Palette.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0),
                        ],
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Palette.paper))
                          : const Icon(Icons.send,
                              size: 18, color: Palette.paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
