import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_scaffold.dart';
import '../../widgets/simulated_badge.dart';

/// F9: the Mocked capability suite — real UI, simulated data, every surface
/// explicitly labelled SIMULATED. Four panels behind a segmented selector:
/// sandbox execution, AI shortlist (with real human-approve interaction),
/// agent access scopes, and a proof-of-work challenge.
class MockedSuiteScreen extends StatefulWidget {
  const MockedSuiteScreen({super.key});

  @override
  State<MockedSuiteScreen> createState() => _MockedSuiteScreenState();
}

class _MockedSuiteScreenState extends State<MockedSuiteScreen> {
  int _panel = 0;

  static const _panels = ['SANDBOX', 'SHORTLIST', 'AGENT', 'POW'];

  @override
  Widget build(BuildContext context) {
    return BrutalScaffold(
      title: 'Simulated Suite',
      titleBarColor: Palette.tomato,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                for (var i = 0; i < _panels.length; i++) ...[
                  BrutalBadge(
                    label: _panels[i],
                    color: Palette.tomato,
                    textColor:
                        _panel == i ? Palette.paper : Palette.ink,
                    selected: _panel == i,
                    onTap: () => setState(() => _panel = i),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _panel,
              children: const [
                _SandboxPanel(),
                _ShortlistPanel(),
                _AgentAccessPanel(),
                _PowPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1 · Sandbox: a pre-scripted execution log that "streams" in.
// ---------------------------------------------------------------------------

class _SandboxPanel extends StatefulWidget {
  const _SandboxPanel();

  @override
  State<_SandboxPanel> createState() => _SandboxPanelState();
}

class _SandboxPanelState extends State<_SandboxPanel> {
  static const _script = [
    r'$ sandbox init --repo wave5-demo/growth --tier claim_an_issue',
    'sandbox: provisioning ephemeral container (simulated)',
    'sandbox: cloning repository… done (2.1s)',
    r'$ pytest -q',
    '..................... 21 passed in 3.4s',
    r'$ sandbox permissions',
    'read: src/**  write: src/features/growth/**  network: DENIED',
    'sandbox: candidate changes isolated from main branch',
    'sandbox: session recorded for maintainer review',
    '— end of simulated log —',
  ];

  final List<String> _lines = [];
  final _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_lines.length >= _script.length) {
        timer.cancel();
        return;
      }
      setState(() => _lines.add(_script[_lines.length]));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController
              .jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BrutalCard(
        accent: Palette.tomato,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('CONTRIBUTION SANDBOX',
                    style: AppType.mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Palette.ink400)),
                const Spacer(),
                const SimulatedBadge(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'In the live product, applicants get an isolated sandbox on the '
              'repo. This is a scripted replay — no code is executed.',
              style: AppType.body(size: 12, color: Palette.ink600),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 320,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.ink,
                border: Border.all(color: Palette.ink, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _lines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _lines[index],
                    style: AppType.mono(
                      size: 12,
                      color: _lines[index].startsWith(r'$')
                          ? Palette.lime
                          : Palette.paper,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · AI shortlist: preset candidates, REAL human-approve interaction.
// ---------------------------------------------------------------------------

class _ShortlistPanel extends StatefulWidget {
  const _ShortlistPanel();

  @override
  State<_ShortlistPanel> createState() => _ShortlistPanelState();
}

class _ShortlistCandidate {
  _ShortlistCandidate(this.login, this.role, this.rationale);
  final String login;
  final String role;
  final String rationale;
  String state = 'pending'; // pending | approved | rejected
}

class _ShortlistPanelState extends State<_ShortlistPanel> {
  final _candidates = [
    _ShortlistCandidate('aisha-r', 'collaborator',
        'Strong Postgres history; 9/12 active weeks; 4.8★ peer average.'),
    _ShortlistCandidate('mei-designs', 'collaborator',
        'Design-system portfolio matches your Soft Brutalist direction.'),
    _ShortlistCandidate('marcus-cto', 'founder',
        'Fintech domain overlap; hiring history suggests team fit.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text('AI SHORTLIST',
                style: AppType.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Palette.ink400)),
            const Spacer(),
            const SimulatedBadge(label: 'SIMULATED RANKING'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'The ranking below is preset demo data. Your approve/reject choices '
          'are real interactions — the AI never auto-contacts anyone.',
          style: AppType.body(size: 12, color: Palette.ink600),
        ),
        const SizedBox(height: 14),
        for (final candidate in _candidates) ...[
          BrutalCard(
            flat: true,
            accent: switch (candidate.state) {
              'approved' => Palette.lime,
              'rejected' => Palette.ink200,
              _ => Palette.mustard,
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('@${candidate.login}',
                        style: AppType.display(size: 17)),
                    const Spacer(),
                    BrutalBadge(
                        label: candidate.state.toUpperCase(),
                        color: switch (candidate.state) {
                          'approved' => Palette.lime,
                          'rejected' => Palette.ink200,
                          _ => Palette.mustard,
                        }),
                  ],
                ),
                const SizedBox(height: 8),
                Text(candidate.rationale,
                    style: AppType.body(size: 13, height: 1.35)),
                if (candidate.state == 'pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Approve',
                          color: Palette.lime,
                          textColor: Palette.ink,
                          onPressed: () => setState(
                              () => candidate.state = 'approved'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BrutalButton(
                          label: 'Reject',
                          color: Palette.cream100,
                          textColor: Palette.tomato,
                          onPressed: () => setState(
                              () => candidate.state = 'rejected'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · Agent access panel: scope toggles (mock persistence in state).
// ---------------------------------------------------------------------------

class _AgentAccessPanel extends StatefulWidget {
  const _AgentAccessPanel();

  @override
  State<_AgentAccessPanel> createState() => _AgentAccessPanelState();
}

class _AgentAccessPanelState extends State<_AgentAccessPanel> {
  final Map<String, bool> _scopes = {
    'Read project cards': true,
    'Draft growth updates': true,
    'Reply to collab requests': false,
    'Publish role postings': false,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text('AGENT ACCESS',
                style: AppType.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Palette.ink400)),
            const Spacer(),
            const SimulatedBadge(),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Scoped access an AI agent WOULD get on your behalf. Toggles are '
          'local demo state — no agent is connected.',
          style: AppType.body(size: 12, color: Palette.ink600),
        ),
        const SizedBox(height: 14),
        BrutalCard(
          child: Column(
            children: [
              for (final entry in _scopes.entries) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.key,
                          style: AppType.body(
                              size: 14, weight: FontWeight.w600)),
                    ),
                    Switch(
                      value: entry.value,
                      activeThumbColor: Palette.lime,
                      onChanged: (value) =>
                          setState(() => _scopes[entry.key] = value),
                    ),
                  ],
                ),
                if (entry.key != _scopes.keys.last)
                  const Divider(color: Palette.ink200),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        BrutalCard(
          background: Palette.cream100,
          padding: const EdgeInsets.all(12),
          child: Text(
            'Every agent action would be logged and human-reviewable, '
            'mirroring the sandbox audit trail.',
            style: AppType.body(size: 12, color: Palette.ink600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · Proof-of-work challenge: an animated "solve" with a verified end state.
// ---------------------------------------------------------------------------

class _PowPanel extends StatefulWidget {
  const _PowPanel();

  @override
  State<_PowPanel> createState() => _PowPanelState();
}

class _PowPanelState extends State<_PowPanel> {
  double _progress = 0;
  bool _running = false;
  Timer? _timer;

  void _start() {
    if (_running) return;
    setState(() {
      _running = true;
      _progress = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      setState(() => _progress += 0.04);
      if (_progress >= 1) {
        timer.cancel();
        setState(() {
          _progress = 1;
          _running = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _progress >= 1;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text('PROOF-OF-WORK CHALLENGE',
                style: AppType.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Palette.ink400)),
            const Spacer(),
            const SimulatedBadge(),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'An anti-spam gate before sending bulk requests: the client solves '
          'a small hash puzzle. This demo animates a scripted solve.',
          style: AppType.body(size: 12, color: Palette.ink600),
        ),
        const SizedBox(height: 14),
        BrutalCard(
          accent: done ? Palette.lime : Palette.mustard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('challenge: sha256(nonce + "builder-plaza") < 2^236',
                  style: AppType.mono(size: 12, color: Palette.ink600)),
              const SizedBox(height: 12),
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Palette.cream100,
                  border: Border.all(color: Palette.ink, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progress.clamp(0, 1),
                    child: Container(
                        color: done ? Palette.lime : Palette.teal),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (done)
                Row(
                  children: [
                    const Icon(Icons.verified,
                        size: 18, color: Palette.ink),
                    const SizedBox(width: 6),
                    Text('nonce found: 0x2f9a11 · challenge passed',
                        style: AppType.mono(
                            size: 12, weight: FontWeight.w700)),
                  ],
                )
              else
                BrutalButton(
                  label: _running ? 'Solving…' : 'Solve challenge',
                  color: Palette.teal,
                  loading: _running,
                  onPressed: _running ? null : _start,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
