import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_card.dart';

/// Landing screen: pings `/health` and `/health/db` so backend wiring problems
/// are obvious before we ever try to log in.
class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  _CheckState _health = const _CheckState.loading();
  _CheckState _db = const _CheckState.loading();

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _health = const _CheckState.loading();
      _db = const _CheckState.loading();
    });

    final dio = ApiClient.instance.dio;

    try {
      final res = await dio.get<Map<String, dynamic>>('/health');
      final env = res.data?['environment'] ?? 'unknown';
      setState(() => _health = _CheckState.ok('Backend OK — environment: $env'));
    } catch (e) {
      setState(() => _health = _CheckState.error(ApiClient.describeError(e)));
    }

    try {
      final res = await dio.get<Map<String, dynamic>>('/health/db');
      final count = res.data?['users_count'] ?? '?';
      setState(() => _db = _CheckState.ok('DB OK — users: $count'));
    } catch (e) {
      setState(() => _db = _CheckState.error(ApiClient.describeError(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text('BUILDER\nPLAZA',
                      style: AppType.display(size: 44, height: 0.95)),
                  const SizedBox(height: 8),
                  Text('System check',
                      style: AppType.body(
                          size: 15, color: Palette.ink600)),
                  const SizedBox(height: 24),
                  _CheckCard(state: _health, label: 'API'),
                  const SizedBox(height: 16),
                  _CheckCard(state: _db, label: 'DATABASE'),
                  const SizedBox(height: 16),
                  BrutalCard(
                    background: Palette.cream100,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('BASE URL  ',
                            style: AppType.mono(
                                size: 11,
                                color: Palette.ink400,
                                weight: FontWeight.w700)),
                        Expanded(
                          child: Text(apiBaseUrl,
                              style: AppType.mono(size: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  BrutalButton(
                    label: 'Retry checks',
                    color: Palette.cream100,
                    textColor: Palette.ink,
                    onPressed: _runChecks,
                  ),
                  const SizedBox(height: 12),
                  BrutalButton(
                    label: 'Continue → Login',
                    color: Palette.teal,
                    onPressed: () => context.go('/login'),
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

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.state, required this.label});

  final _CheckState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (accent, bg) = switch (state.status) {
      _Status.loading => (Palette.mustard, Palette.paper),
      _Status.ok => (Palette.lime, Palette.paper),
      _Status.error => (Palette.tomato, const Color(0xFFFFF1EE)),
    };

    return BrutalCard(
      accent: accent,
      background: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: AppType.mono(
                      size: 11,
                      color: Palette.ink400,
                      weight: FontWeight.w700)),
              const Spacer(),
              if (state.status == _Status.loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Palette.ink400),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: AppType.body(
                size: 15,
                weight: FontWeight.w600,
                color: state.status == _Status.error
                    ? Palette.tomato
                    : Palette.ink),
          ),
        ],
      ),
    );
  }
}

enum _Status { loading, ok, error }

class _CheckState {
  const _CheckState.loading()
      : status = _Status.loading,
        message = 'Checking…';
  const _CheckState.ok(this.message) : status = _Status.ok;
  const _CheckState.error(this.message) : status = _Status.error;

  // Both fields are always initialized by the constructors above.

  final _Status status;
  final String message;
}
