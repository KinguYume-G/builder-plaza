import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/auth_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/onboarding_step_header.dart';

/// STEP 2 of the Trust Gateway, LIVE variant: a REAL LinkedIn OpenID Connect
/// sign-in step (used when the backend reports `mode == "live"` per ADR-0003).
///
/// Because this binds a real identity there is deliberately NO "SIMULATED"
/// watermark — instead a small, honest "Real LinkedIn OIDC" note. Tapping the
/// button asks the backend for an `authorize_url` and performs a full-page,
/// same-tab browser redirect to LinkedIn. LinkedIn (via the backend callback)
/// then redirects the browser back to `/#/onboarding/role?linkedin=ok`
/// (or `?linkedin=error` / `?linkedin=conflict`).
class LinkedInLiveScreen extends StatefulWidget {
  const LinkedInLiveScreen({super.key, this.result});

  /// The `?linkedin=` query param the browser came back with, if any:
  /// `error` or `conflict` surface a retryable error here. `ok` never lands on
  /// this screen (gating advances a bound user to role selection).
  final String? result;

  @override
  State<LinkedInLiveScreen> createState() => _LinkedInLiveScreenState();
}

class _LinkedInLiveScreenState extends State<LinkedInLiveScreen> {
  bool _redirecting = false;
  String? _launchError;

  bool get _hasReturnError =>
      widget.result == 'error' || widget.result == 'conflict';

  Future<void> _signIn() async {
    setState(() {
      _redirecting = true;
      _launchError = null;
    });

    final auth = context.read<AuthProvider>();
    final url = await auth.linkedInLoginUrl();
    if (!mounted) return;

    if (url == null || url.isEmpty) {
      setState(() {
        _redirecting = false;
        _launchError = auth.error ?? 'Could not start LinkedIn sign-in.';
      });
      return;
    }

    // Full-page, same-tab redirect. On Flutter web `webOnlyWindowName: '_self'`
    // navigates the current tab (rather than opening a popup), so LinkedIn's
    // OIDC screen replaces the app and the callback can bring the browser back.
    try {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _redirecting = false;
        _launchError = 'Could not open LinkedIn. Please try again.';
      });
    }
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingStepHeader(
                    step: 'STEP 2',
                    title: 'CONFIRM IDENTITY',
                    subtitle:
                        'Sign in with LinkedIn so founders can trust who they '
                        'are collaborating with.',
                    accent: Palette.plum,
                  ),
                  const SizedBox(height: 16),
                  // Honest, low-key provenance note. This is a REAL identity
                  // step, so it is NOT watermarked "SIMULATED".
                  BrutalCard(
                    accent: Palette.cobalt,
                    background: Palette.cream100,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            color: Palette.ink, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Real LinkedIn OIDC · you will be redirected to '
                            'linkedin.com',
                            style: AppType.mono(
                                size: 11, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BrutalCard(
                    accent: Palette.plum,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SIGN IN',
                            style: AppType.display(size: 20, height: 1.05)),
                        const SizedBox(height: 8),
                        Text(
                          'You will leave Builder Plaza briefly to authorize '
                          'with LinkedIn, then return here automatically.',
                          style: AppType.body(
                              size: 14, height: 1.35, color: Palette.ink600),
                        ),
                        const SizedBox(height: 16),
                        BrutalButton(
                          label: 'Sign in with LinkedIn',
                          color: Palette.plum,
                          loading: _redirecting || auth.loading,
                          onPressed:
                              _redirecting || auth.loading ? null : _signIn,
                        ),
                      ],
                    ),
                  ),
                  if (_hasReturnError || _launchError != null) ...[
                    const SizedBox(height: 16),
                    BrutalCard(
                      accent: Palette.tomato,
                      background: const Color(0xFFFFF1EE),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage(),
                            style: AppType.body(
                                size: 14, color: Palette.tomato),
                          ),
                          const SizedBox(height: 12),
                          BrutalButton(
                            label: 'Try again',
                            color: Palette.tomato,
                            loading: _redirecting || auth.loading,
                            onPressed: _redirecting || auth.loading
                                ? null
                                : _signIn,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage() {
    if (_launchError != null) return _launchError!;
    if (widget.result == 'conflict') {
      return 'That LinkedIn account is already linked to another Builder '
          'Plaza profile. Sign in with a different LinkedIn account.';
    }
    return 'LinkedIn sign-in did not complete. Please try again.';
  }
}
