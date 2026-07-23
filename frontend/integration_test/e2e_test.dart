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

/// Scrolls [finder] into view before tapping it.
///
/// A bare `tester.tap()` computes the widget's offset and fires a pointer
/// event there even when that offset is off-screen, which silently misses.
/// This bit on a CI emulator whose viewport is 890px tall while CREATE
/// PROJECT sat at y=959, and would bite again on any short device -- the
/// Device Farm pool spans phones and tablets with very different geometry.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  try {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 300));
  } on StateError {
    // No Scrollable ancestor -- nothing to scroll, tap where it already is.
  }
  await tester.tap(target);
  await tester.pump();
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
    await _tapVisible(tester, find.text('CONNECT GITHUB'));

    // Either the fresh flow continues (summary + Next), or this account
    // already onboarded on a previous run and we land straight on Home.
    await _pumpUntilFound(
      tester,
      find.byWidgetPredicate((widget) =>
          widget is Text &&
          (widget.data == 'NEXT →' || widget.data == 'BUILDER HOME')),
    );

    if (find.text('NEXT →').evaluate().isNotEmpty) {
      await _tapVisible(tester, find.text('NEXT →'));

      // Step 2: simulated LinkedIn consent — pick the first preset persona.
      // The screen is watermarked SIMULATED FOR DEMO (ADR-0003).
      await _pumpUntilFound(tester, find.textContaining('Ryan Tan'));
      await _tapVisible(tester, find.textContaining('Ryan Tan').first);

      // Step 3: choose the Builder role.
      await _pumpUntilFound(tester, find.text('CHOOSE YOUR VIEW'));
      await _tapVisible(tester, find.text('BUILDER'));
    }

    await _pumpUntilFound(tester, find.text('BUILDER HOME'));
    expect(find.text('MY PROJECTS'), findsOneWidget);

    // ---------- E2E-2 · post a project card ----------
    await _tapVisible(tester, find.text('＋ NEW PROJECT'));
    await _pumpUntilFound(tester, find.text('TITLE'));

    final title =
        'E2E Project ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await tester.enterText(find.byType(TextField).first, title);
    // Stage chips: pick "Prototype".
    await _tapVisible(tester, find.text('PROTOTYPE').first);
    await _tapVisible(tester, find.text('CREATE PROJECT'));

    // Success state offers "View project"; go back home instead.
    await _pumpUntilFound(tester, find.text('VIEW PROJECT'));
    await tester.pageBack();
    await _pumpUntilFound(tester, find.text('BUILDER HOME'));
    await _pumpUntilFound(tester, find.textContaining('E2E Project'));

    // ---------- E2E-3 · match → structured request ----------
    await _tapVisible(tester, find.text('MATCH'));
    await _pumpUntilFound(tester, find.text('CREDIBILITY'),
        timeout: const Duration(seconds: 45)); // engine may embed first time

    await _tapVisible(tester, find.text('CREDIBILITY').first);
    await _pumpUntilFound(tester, find.text('REQUEST COLLABORATION'));
    await _tapVisible(tester, find.text('REQUEST COLLABORATION'));
    await _pumpUntilFound(tester, find.textContaining('REQUEST →'));

    await tester.enterText(find.byType(TextField).last,
        'E2E pitch: I ship weekly and want to collaborate on your project.');
    await _tapVisible(tester, find.text('SEND REQUEST'));
    await _pumpUntilFound(tester, find.textContaining('Request sent'));

    // Verify it shows under SENT in the requests screen.
    await _pumpUntilFound(tester, find.text('BUILDER HOME'));
    await _tapVisible(tester, find.text('HOME'));
    await _tapVisible(tester, find.text('REQUESTS & MESSAGES'));
    await _pumpUntilFound(tester, find.text('SENT'));
    await _tapVisible(tester, find.text('SENT'));
    await _pumpUntilFound(tester, find.text('PENDING'));
  });
}
