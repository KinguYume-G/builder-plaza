import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/github_summary.dart';
import '../../state/auth_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/onboarding_step_header.dart';

/// STEP 1 of the Trust Gateway: verify the user's work by connecting a public
/// GitHub account. On success we show a summary of their public activity.
class GithubConnectScreen extends StatefulWidget {
  const GithubConnectScreen({super.key});

  @override
  State<GithubConnectScreen> createState() => _GithubConnectScreenState();
}

class _GithubConnectScreenState extends State<GithubConnectScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Hands the user off to sign-in, carrying the username they already typed.
  /// Clears the connect error first — otherwise the sign-in screen opens
  /// displaying the very 409 the user just acted on.
  void _goToSignIn() {
    final login = _controller.text.trim();
    context.read<AuthProvider>().clearError();
    context.go(Uri(
      path: '/login',
      queryParameters: login.isEmpty ? null : {'login': login},
    ).toString());
  }

  Future<void> _connect() async {
    final login = _controller.text.trim();
    if (login.isEmpty) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().connectGithub(login);
    // Router redirect + local rebuild handle navigation on success.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final summary = auth.githubSummary;
    final connected = auth.currentUser?.githubConnected ?? false;

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
                    step: 'STEP 1',
                    title: 'VERIFY YOUR WORK',
                    subtitle:
                        'Connect a public GitHub account so founders can see '
                        'what you actually build.',
                    accent: Palette.teal,
                  ),
                  const SizedBox(height: 24),
                  BrutalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GITHUB USERNAME',
                            style: AppType.mono(
                                size: 11,
                                color: Palette.ink400,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          style: AppType.mono(size: 16, weight: FontWeight.w600),
                          cursorColor: Palette.teal,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _connect(),
                          decoration: InputDecoration(
                            hintText: 'octocat',
                            hintStyle: AppType.mono(
                                size: 16, color: Palette.ink400),
                            filled: true,
                            fillColor: Palette.paper,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
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
                        const SizedBox(height: 16),
                        BrutalButton(
                          label: 'Connect GitHub',
                          color: Palette.teal,
                          loading: auth.loading,
                          onPressed: auth.loading ? null : _connect,
                        ),
                      ],
                    ),
                  ),
                  if (auth.error != null && summary == null) ...[
                    const SizedBox(height: 16),
                    BrutalCard(
                      accent: Palette.tomato,
                      background: const Color(0xFFFFF1EE),
                      child: Text(
                        _friendlyError(auth.error!),
                        style: AppType.body(size: 14, color: Palette.tomato),
                      ),
                    ),
                    if (_isExistingAccount(auth.error!)) ...[
                      const SizedBox(height: 12),
                      BrutalButton(
                        label: 'Sign in instead →',
                        color: Palette.teal,
                        onPressed: () => _goToSignIn(),
                      ),
                    ],
                  ],
                  if (summary != null) ...[
                    const SizedBox(height: 20),
                    _SummaryCard(summary: summary),
                    const SizedBox(height: 20),
                    BrutalButton(
                      label: 'Next →',
                      color: connected ? Palette.lime : Palette.teal,
                      textColor: Palette.ink,
                      onPressed: () => context.go('/onboarding/linkedin'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DevLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('404')) {
      return "We couldn't find that GitHub user. Check the spelling and try "
          'again.';
    }
    if (raw.contains('409')) {
      return 'That account is already set up on Builder Plaza. Sign in to it '
          'instead of connecting it again.';
    }
    if (raw.contains('502')) {
      return 'GitHub is temporarily unreachable. Please try again in a moment.';
    }
    return raw;
  }

  /// A 409 means the account exists — the only thing the user can do about it
  /// is sign in, so offer that rather than leaving them on a dead end. The old
  /// copy told them to "sign in with GitHub OAuth instead", which the app has
  /// no entry point for at all.
  bool _isExistingAccount(String raw) => raw.contains('409');
}

/// The result card shown after a successful connect: avatar, name, handle, and
/// brutalist badges summarizing public activity.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final GithubSummary summary;

  @override
  Widget build(BuildContext context) {
    final topLangs = summary.topLanguages.take(3).toList();

    return BrutalCard(
      accent: Palette.lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(url: summary.avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.name ?? summary.login,
                      style: AppType.display(size: 22, height: 1.05),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('@${summary.login}',
                        style: AppType.mono(
                            size: 13, color: Palette.ink600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalBadge(
                  label: '${summary.publicRepos} repos', color: Palette.mustard),
              BrutalBadge(
                  label: '${summary.followers} followers',
                  color: Palette.teal,
                  textColor: Palette.paper),
              for (final lang in topLangs)
                BrutalBadge(
                    label: '${lang.language} ${lang.count}',
                    color: Palette.paper,
                    textColor: Palette.ink),
              BrutalBadge(
                  label: '${summary.recentActivityCount} recent',
                  color: Palette.lime),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Palette.cream100,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person, color: Palette.ink400)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person, color: Palette.ink400),
            ),
    );
  }
}

/// A small link back to the dev tools, so debugging stays easy during the demo.
class _DevLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => context.go('/dev'),
        child: Text('dev · system check',
            style: AppType.mono(size: 11, color: Palette.ink400)),
      ),
    );
  }
}
