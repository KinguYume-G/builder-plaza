import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/linkedin_profile.dart';
import '../../state/auth_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/onboarding_step_header.dart';
import '../../widgets/simulated_watermark.dart';

/// STEP 2 of the Trust Gateway: a MOCK consent screen where the user picks a
/// simulated LinkedIn identity to bind.
///
/// This screen is deliberately watermarked "SIMULATED FOR DEMO" (ribbon +
/// diagonal tiling) so it can never be mistaken for the real LinkedIn — an
/// academic-integrity requirement.
class LinkedInSimulatedScreen extends StatefulWidget {
  const LinkedInSimulatedScreen({super.key});

  @override
  State<LinkedInSimulatedScreen> createState() =>
      _LinkedInSimulatedScreenState();
}

class _LinkedInSimulatedScreenState extends State<LinkedInSimulatedScreen> {
  List<LinkedInProfile> _profiles = const [];
  bool _loadingList = true;
  String? _bindingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final profiles =
        await context.read<AuthProvider>().fetchLinkedInProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loadingList = false;
    });
  }

  Future<void> _select(LinkedInProfile profile) async {
    setState(() => _bindingId = profile.id);
    final ok = await context.read<AuthProvider>().bindLinkedIn(profile.id);
    if (!mounted) return;
    setState(() => _bindingId = null);
    if (ok) context.go('/onboarding/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.cream50,
      body: SimulatedWatermark(
        child: SafeArea(
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
                      step: 'STEP 2',
                      title: 'CONFIRM IDENTITY',
                      subtitle:
                          'Choose a professional identity to link. These '
                          'profiles are simulated for this demo.',
                      accent: Palette.copper,
                    ),
                    const SizedBox(height: 16),
                    // A loud inline disclaimer in addition to the watermark.
                    BrutalCard(
                      accent: Palette.mustard,
                      background: Palette.cream100,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Palette.ink, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'MOCK CONSENT · NOT REAL LINKEDIN · '
                              'SIMULATED FOR DEMO',
                              style: AppType.mono(
                                  size: 11, weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._buildList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    if (_loadingList) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
            child: CircularProgressIndicator(color: Palette.ink),
          ),
        ),
      ];
    }

    if (_profiles.isEmpty) {
      final err = context.read<AuthProvider>().error;
      return [
        BrutalCard(
          accent: Palette.tomato,
          background: const Color(0xFFFFF1EE),
          child: Text(
            err ?? 'No profiles available.',
            style: AppType.body(size: 14, color: Palette.tomato),
          ),
        ),
      ];
    }

    return [
      for (final p in _profiles) ...[
        _ProfileCard(
          profile: p,
          binding: _bindingId == p.id,
          disabled: _bindingId != null && _bindingId != p.id,
          onTap: () => _select(p),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }
}

/// A single selectable simulated profile.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.binding,
    required this.disabled,
    required this.onTap,
  });

  final LinkedInProfile profile;
  final bool binding;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: BrutalCard(
          accent: Palette.copper,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: AppType.display(size: 20, height: 1.05)),
                    const SizedBox(height: 6),
                    Text(profile.headline,
                        style: AppType.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Palette.ink600)),
                    const SizedBox(height: 10),
                    Text('${profile.company} · ${profile.title}',
                        style: AppType.mono(
                            size: 12, color: Palette.ink600)),
                    const SizedBox(height: 10),
                    BrutalBadge(
                      label: '${_tenure(profile.tenureYears)} yrs',
                      color: Palette.copper,
                      textColor: Palette.paper,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (binding)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Palette.ink),
                )
              else
                const Icon(Icons.chevron_right, color: Palette.ink),
            ],
          ),
        ),
      ),
    );
  }

  String _tenure(double years) {
    return years == years.roundToDouble()
        ? years.toStringAsFixed(0)
        : years.toStringAsFixed(1);
  }
}
