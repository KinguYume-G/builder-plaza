import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/onboarding_step_header.dart';

/// STEP 3 of the Trust Gateway: choose a Primary Role. This sets the lens the
/// shared Home is rendered through.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  String? _submitting;

  static const _roles = <_RoleOption>[
    _RoleOption(
      role: 'builder',
      title: 'BUILDER',
      blurb: 'make products, publish progress',
      color: Palette.cobalt,
      onColor: Palette.paper,
      icon: Icons.build,
    ),
    _RoleOption(
      role: 'collaborator',
      title: 'COLLABORATOR',
      blurb: 'join & contribute to projects',
      color: Palette.lime,
      onColor: Palette.ink,
      icon: Icons.groups,
    ),
    _RoleOption(
      role: 'founder',
      title: 'FOUNDER',
      blurb: 'hire & shortlist talent',
      color: Palette.mustard,
      onColor: Palette.ink,
      icon: Icons.rocket_launch,
    ),
  ];

  Future<void> _pick(String role) async {
    setState(() => _submitting = role);
    final ok = await context.read<AuthProvider>().confirmRole(role);
    if (!mounted) return;
    setState(() => _submitting = null);
    if (ok) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting != null;

    return Scaffold(
      backgroundColor: Palette.cream50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingStepHeader(
                    step: 'STEP 3',
                    title: 'CHOOSE YOUR VIEW',
                    subtitle:
                        'Pick your primary role. You can switch it later from '
                        'your home.',
                    accent: Palette.lime,
                  ),
                  const SizedBox(height: 24),
                  for (final option in _roles) ...[
                    _RoleCard(
                      option: option,
                      loading: _submitting == option.role,
                      disabled: busy && _submitting != option.role,
                      onTap: () => _pick(option.role),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.role,
    required this.title,
    required this.blurb,
    required this.color,
    required this.onColor,
    required this.icon,
  });

  final String role;
  final String title;
  final String blurb;
  final Color color;
  final Color onColor;
  final IconData icon;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final _RoleOption option;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: BrutalCard(
          background: option.color,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(option.icon, color: option.onColor, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        style: AppType.display(
                            size: 24, color: option.onColor, height: 1.0)),
                    const SizedBox(height: 6),
                    Text(option.blurb,
                        style: AppType.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: option.onColor)),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(option.onColor)),
                )
              else
                Icon(Icons.arrow_forward, color: option.onColor),
            ],
          ),
        ),
      ),
    );
  }
}
