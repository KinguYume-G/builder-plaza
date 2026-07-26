import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/project_card.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_field.dart';
import '../../widgets/brutal_scaffold.dart';

/// Lets the user advertise (or clear) a single collaboration intent, shown as a
/// plum badge on their projects across the Plaza.
class IntentEditorScreen extends StatefulWidget {
  const IntentEditorScreen({super.key});

  @override
  State<IntentEditorScreen> createState() => _IntentEditorScreenState();
}

class _IntentEditorScreenState extends State<IntentEditorScreen> {
  final _noteController = TextEditingController();
  String? _selected;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final intent = await context.read<ProjectsProvider>().getIntent();
    if (!mounted) return;
    setState(() {
      _selected = intent?.intentType;
      _noteController.text = intent?.note ?? '';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final type = _selected;
    if (type == null) return;
    setState(() => _saving = true);
    final ok = await context
        .read<ProjectsProvider>()
        .setIntent(type, note: _noteController.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok != null) _leave();
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final ok = await context.read<ProjectsProvider>().clearIntent();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectsProvider>();

    return BrutalScaffold(
      title: 'Intent',
      titleBarColor: Palette.copper,
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Palette.ink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('WHAT ARE YOU\nOPEN TO?',
                          style: AppType.display(size: 30, height: 1.0)),
                      const SizedBox(height: 8),
                      Text(
                        'Founders and collaborators see this on your projects.',
                        style: AppType.body(size: 14, color: Palette.ink600),
                      ),
                      const SizedBox(height: 20),
                      BrutalCard(
                        accent: Palette.copper,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INTENT',
                                style: AppType.mono(
                                    size: 11,
                                    color: Palette.ink400,
                                    weight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final type in kIntentTypes)
                                  BrutalBadge(
                                    label: intentLabel(type),
                                    color: Palette.copper,
                                    textColor: Palette.paper,
                                    selected: _selected == type,
                                    onTap: () =>
                                        setState(() => _selected = type),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            BrutalField(
                              label: 'Note (optional)',
                              controller: _noteController,
                              hintText: 'e.g. looking for a design partner',
                              maxLines: 3,
                              maxLength: 200,
                            ),
                          ],
                        ),
                      ),
                      if (projects.error != null) ...[
                        const SizedBox(height: 16),
                        BrutalCard(
                          accent: Palette.tomato,
                          background: const Color(0xFFFFF1EE),
                          child: Text(projects.error!,
                              style: AppType.body(
                                  size: 14, color: Palette.tomato)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      BrutalButton(
                        label: 'Save intent',
                        color: Palette.copper,
                        loading: _saving,
                        onPressed: (_selected == null || _saving) ? null : _save,
                      ),
                      const SizedBox(height: 12),
                      BrutalButton(
                        label: 'Clear intent',
                        color: Palette.cream100,
                        textColor: Palette.ink,
                        onPressed: _saving ? null : _clear,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
