// Verifies HomeShell's adaptive navigation: a bottom nav below
// kWideLayoutBreakpoint, a side rail at or above it (dev doc §15 / MAE
// rubric "Mobile Adaptive Design").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:builder_plaza/models/user.dart';
import 'package:builder_plaza/screens/home/home_shell.dart';
import 'package:builder_plaza/state/auth_provider.dart';
import 'package:builder_plaza/state/growth_provider.dart';
import 'package:builder_plaza/state/matches_provider.dart';
import 'package:builder_plaza/state/projects_provider.dart';

const _testUser = User(
  id: 'u1',
  githubLogin: 'octocat',
  primaryRole: 'builder',
  completenessPct: 40,
  trustScore: 0,
  reverifyFlag: false,
  onboardingComplete: true,
  githubConnected: true,
  linkedinConnected: true,
);

Widget _wrapHomeShell() {
  final auth = AuthProvider()..debugSetUser(_testUser);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ProjectsProvider>(create: (_) => ProjectsProvider()),
      ChangeNotifierProvider<GrowthProvider>(create: (_) => GrowthProvider()),
      ChangeNotifierProvider<MatchesProvider>(create: (_) => MatchesProvider()),
    ],
    child: const MaterialApp(home: HomeShell()),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Not pumpAndSettle: providers keep retrying failed network calls off a
  // running app (none is up in this test), so just pump a few frames.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeShell shows the bottom nav below the wide breakpoint',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapHomeShell());
    await _settle(tester);

    expect(find.byKey(const Key('home_shell_narrow_layout')), findsOneWidget);
    expect(find.byKey(const Key('home_shell_wide_layout')), findsNothing);
  });

  testWidgets('HomeShell shows a side rail at/above the wide breakpoint',
      (tester) async {
    tester.view.physicalSize = Size(kWideLayoutBreakpoint + 200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapHomeShell());
    await _settle(tester);

    expect(find.byKey(const Key('home_shell_wide_layout')), findsOneWidget);
    expect(find.byKey(const Key('home_shell_narrow_layout')), findsNothing);
  });
}
