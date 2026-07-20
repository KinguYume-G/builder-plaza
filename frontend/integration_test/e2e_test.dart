// End-to-end tests (E2E-1/2/3) against a LIVE local backend.
//
// Prerequisites:
//   1. backend running:  cd backend && .venv/bin/uvicorn app.main:app --port 8000
//   2. seeded database:  cd backend && .venv/bin/python seed.py
//   3. LINKEDIN_MODE=simulated (the default) — E2E flows hit the simulated
//      consent screen only, never real LinkedIn.
//
// Run:  flutter test integration_test  (or -d chrome / a device)
//
// E2E-1  Trust Gateway onboarding: GitHub connect → simulated LinkedIn
//        consent → role pick → role home.
// E2E-2  Builder posts a project card → it appears under MY PROJECTS.
// E2E-3  Matching → credibility sheet → structured collab request → the
//        request shows in SENT (controlled DM: no free-form first contact).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:builder_plaza/main.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E-1/2/3: onboarding → project → match request',
      (tester) async {
    SharedPreferences.setMockInitialValues({}); // fresh session, no token
    await tester.pumpWidget(const BuilderPlazaApp());

    // ---------- E2E-1 · onboarding ----------
    await _pumpUntilFound(tester, find.text('VERIFY YOUR WORK'));

    // Step 1: connect a REAL public GitHub account.
    await tester.enterText(find.byType(TextField).first, 'octocat');
    await tester.tap(find.text('CONNECT GITHUB'));
    await tester.pump();

    // Either the fresh flow continues (summary + Next), or this account
    // already onboarded on a previous run and we land straight on Home.
    await _pumpUntilFound(
      tester,
      find.byWidgetPredicate((widget) =>
          widget is Text &&
          (widget.data == 'NEXT →' || widget.data == 'BUILDER HOME')),
    );

    if (find.text('NEXT →').evaluate().isNotEmpty) {
      await tester.tap(find.text('NEXT →'));
      await tester.pump();

      // Step 2: simulated LinkedIn consent — pick the first preset persona.
      // The screen is watermarked SIMULATED FOR DEMO (ADR-0003).
      await _pumpUntilFound(tester, find.textContaining('Ryan Tan'));
      await tester.tap(find.textContaining('Ryan Tan').first);
      await tester.pump();

      // Step 3: choose the Builder role.
      await _pumpUntilFound(tester, find.text('CHOOSE YOUR VIEW'));
      await tester.tap(find.text('BUILDER'));
      await tester.pump();
    }

    await _pumpUntilFound(tester, find.text('BUILDER HOME'));
    expect(find.text('MY PROJECTS'), findsOneWidget);

    // ---------- E2E-2 · post a project card ----------
    await tester.tap(find.text('＋ NEW PROJECT'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('TITLE'));

    final title =
        'E2E Project ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await tester.enterText(find.byType(TextField).first, title);
    // Stage chips: pick "Prototype".
    await tester.tap(find.text('PROTOTYPE').first);
    await tester.pump();
    await tester.tap(find.text('CREATE PROJECT'));

    // Success state offers "View project"; go back home instead.
    await _pumpUntilFound(tester, find.text('VIEW PROJECT'));
    await tester.pageBack();
    await _pumpUntilFound(tester, find.text('BUILDER HOME'));
    await _pumpUntilFound(tester, find.textContaining('E2E Project'));

    // ---------- E2E-3 · match → structured request ----------
    await tester.tap(find.text('MATCH'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('CREDIBILITY'),
        timeout: const Duration(seconds: 45)); // engine may embed first time

    await tester.tap(find.text('CREDIBILITY').first);
    await _pumpUntilFound(tester, find.text('REQUEST COLLABORATION'));
    await tester.tap(find.text('REQUEST COLLABORATION'));
    await _pumpUntilFound(tester, find.textContaining('REQUEST →'));

    await tester.enterText(find.byType(TextField).last,
        'E2E pitch: I ship weekly and want to collaborate on your project.');
    await tester.tap(find.text('SEND REQUEST'));
    await _pumpUntilFound(tester, find.textContaining('Request sent'));

    // Verify it shows under SENT in the requests screen.
    await _pumpUntilFound(tester, find.text('BUILDER HOME'));
    await tester.tap(find.text('HOME'));
    await tester.pump();
    await tester.tap(find.text('REQUESTS & MESSAGES'));
    await _pumpUntilFound(tester, find.text('SENT'));
    await tester.tap(find.text('SENT'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('PENDING'));
  });
}
