import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../theme/palette.dart';
import 'linkedin_live_screen.dart';
import 'linkedin_simulated_screen.dart';

/// STEP 2 of the Trust Gateway: a thin dispatcher that asks the backend which
/// LinkedIn path it is configured for and renders the matching screen.
///
/// - `mode == "simulated"` → the EXISTING watermarked mock consent screen
///   ([LinkedInSimulatedScreen]), unchanged.
/// - `mode == "live"`      → the real LinkedIn OIDC sign-in
///   ([LinkedInLiveScreen]).
///
/// The mode is fetched once on entry (GET `/auth/linkedin/mode`); the provider
/// defaults to the safe simulated path on any failure rather than exposing a
/// broken live flow.
class LinkedInStepScreen extends StatefulWidget {
  const LinkedInStepScreen({super.key, this.result});

  /// The `?linkedin=` query param the browser returned from the OIDC redirect
  /// with (`error` / `conflict`), forwarded to the live screen.
  final String? result;

  @override
  State<LinkedInStepScreen> createState() => _LinkedInStepScreenState();
}

class _LinkedInStepScreenState extends State<LinkedInStepScreen> {
  String? _mode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMode());
  }

  Future<void> _loadMode() async {
    final mode = await context.read<AuthProvider>().fetchLinkedInMode();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Palette.cream50,
        body: Center(child: CircularProgressIndicator(color: Palette.ink)),
      );
    }

    if (_mode == 'live') {
      return LinkedInLiveScreen(result: widget.result);
    }
    return const LinkedInSimulatedScreen();
  }
}
