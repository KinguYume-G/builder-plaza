import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collab.dart';
import '../state/collab_provider.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brutal_badge.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_card.dart';

/// F7: the structured first-contact form — a typed intent + a substantive
/// pitch (min 20 chars). Opened as a bottom sheet from a match card.
Future<void> showRequestFormSheet(
  BuildContext context, {
  required String toUserId,
  required String toUserLogin,
  String? contextRef,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _RequestForm(
        toUserId: toUserId,
        toUserLogin: toUserLogin,
        contextRef: contextRef,
      ),
    ),
  );
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({
    required this.toUserId,
    required this.toUserLogin,
    this.contextRef,
  });

  final String toUserId;
  final String toUserLogin;
  final String? contextRef;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _pitchController = TextEditingController();
  String _intent = 'collaboration';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _pitchController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final pitch = _pitchController.text.trim();
    if (pitch.length < 20) {
      setState(() =>
          _error = 'Pitch must be at least 20 characters — make your case.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final provider = context.read<CollabProvider>();
    final request = await provider.sendRequest(
      toUser: widget.toUserId,
      intentType: _intent,
      pitch: pitch,
      contextRef: widget.contextRef,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (request != null) {
      // Resolve the messenger BEFORE popping: afterwards this sheet's context
      // is deactivated and ScaffoldMessenger.of(context) can throw.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
            content:
                Text('Request sent to @${widget.toUserLogin}.')),
      );
    } else {
      setState(() => _error = provider.error ?? 'Could not send request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BrutalCard(
          accent: Palette.copper,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('REQUEST → @${widget.toUserLogin}',
                  style: AppType.display(size: 18)),
              const SizedBox(height: 4),
              Text(
                'Structured first contact — no cold DMs. They see your '
                'verified profile with this pitch.',
                style: AppType.body(size: 12, color: Palette.ink600),
              ),
              const SizedBox(height: 14),
              Text('INTENT',
                  style: AppType.mono(
                      size: 10,
                      color: Palette.ink400,
                      weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final intent in kRequestIntentTypes)
                    BrutalBadge(
                      label: kRequestIntentLabels[intent] ?? intent,
                      color: Palette.copper,
                      textColor: _intent == intent
                          ? Palette.paper
                          : Palette.ink,
                      selected: _intent == intent,
                      onTap: () => setState(() => _intent = intent),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pitchController,
                maxLines: 4,
                maxLength: 1000,
                style: AppType.body(size: 14),
                cursorColor: Palette.copper,
                decoration: InputDecoration(
                  hintText:
                      'Why you, why them, why now (min 20 chars)…',
                  hintStyle:
                      AppType.body(size: 13, color: Palette.ink400),
                  filled: true,
                  fillColor: Palette.paper,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: Palette.ink, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: Palette.copper, width: 2.5),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: AppType.body(
                        size: 13, color: Palette.tomato)),
              ],
              const SizedBox(height: 12),
              BrutalButton(
                label: 'Send request',
                color: Palette.copper,
                loading: _sending,
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
