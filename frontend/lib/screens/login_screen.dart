import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brutal_badge.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialLogin});

  /// Pre-fills the login field. Set when we send someone here from the GitHub
  /// connect screen after a 409, so they don't have to retype the username they
  /// just entered (and don't see the unrelated `demo-builder` demo default).
  final String? initialLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _controller;
  String _role = 'builder';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialLogin ?? 'demo-builder',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.devLogin(
      githubLogin: _controller.text.trim(),
      primaryRole: _role,
    );
    if (!mounted) return;
    if (ok) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Palette.cream50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('SIGN IN', style: AppType.display(size: 40)),
                  const SizedBox(height: 24),
                  BrutalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GITHUB LOGIN',
                            style: AppType.mono(
                                size: 11,
                                color: Palette.ink400,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _BrutalField(controller: _controller),
                        const SizedBox(height: 20),
                        Text('ROLE',
                            style: AppType.mono(
                                size: 11,
                                color: Palette.ink400,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in kRoleColors.entries)
                              BrutalBadge(
                                label: entry.key,
                                color: entry.value,
                                selected: _role == entry.key,
                                onTap: () =>
                                    setState(() => _role = entry.key),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    BrutalCard(
                      accent: Palette.tomato,
                      background: const Color(0xFFFFF1EE),
                      child: Text(auth.error!,
                          style: AppType.body(
                              size: 14, color: Palette.tomato)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  BrutalButton(
                    label: 'Dev Login',
                    color: Palette.teal,
                    loading: auth.loading,
                    onPressed: auth.loading ? null : _login,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A TextField styled with a brutalist border to match the design system.
class _BrutalField extends StatelessWidget {
  const _BrutalField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppType.mono(size: 16, weight: FontWeight.w600),
      cursorColor: Palette.teal,
      decoration: InputDecoration(
        filled: true,
        fillColor: Palette.paper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Palette.ink, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Palette.teal, width: 2.5),
        ),
      ),
    );
  }
}
