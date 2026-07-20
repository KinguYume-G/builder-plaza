// Widget tests for the shared Soft Brutalist components and the F4/F9 cards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:builder_plaza/models/growth_post.dart';
import 'package:builder_plaza/widgets/brutal_badge.dart';
import 'package:builder_plaza/widgets/brutal_button.dart';
import 'package:builder_plaza/widgets/growth_post_card.dart';
import 'package:builder_plaza/widgets/simulated_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  setUpAll(() {
    // No network in widget tests: fall back to bundled/platform fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('GrowthPostCard renders summary, count and event types',
      (tester) async {
    final post = GrowthPost.fromJson({
      'id': 'g1',
      'project_id': 'p1',
      'summary': 'Two pushes and a release landed.',
      'trigger': 'scheduled',
      'source_events': [
        {'type': 'PushEvent', 'repo': 'a/b'},
        {'type': 'PushEvent', 'repo': 'a/b'},
        {'type': 'ReleaseEvent', 'repo': 'a/b'},
      ],
    });
    await tester.pumpWidget(_wrap(
        GrowthPostCard(post: post, projectTitle: 'Demo', ownerLogin: 'ada')));

    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
    expect(find.text('Two pushes and a release landed.'), findsOneWidget);
    // BrutalBadge uppercases its labels.
    expect(find.text('3 EVENTS'), findsOneWidget);
    expect(find.text('PUSH'), findsOneWidget); // deduped event types
    expect(find.text('RELEASE'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget); // scheduled trigger label
  });

  testWidgets('SimulatedBadge always shows its label', (tester) async {
    await tester.pumpWidget(_wrap(const SimulatedBadge()));
    expect(find.text('SIMULATED'), findsOneWidget);

    await tester
        .pumpWidget(_wrap(const SimulatedBadge(label: 'SIMULATED RANKING')));
    expect(find.text('SIMULATED RANKING'), findsOneWidget);
  });

  testWidgets('BrutalButton shows a spinner when loading', (tester) async {
    await tester.pumpWidget(_wrap(BrutalButton(
        label: 'Send', color: Colors.blue, loading: true, onPressed: () {})));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('BrutalBadge onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(BrutalBadge(
        label: 'GROWTH', color: Colors.amber, onTap: () => tapped = true)));
    await tester.tap(find.text('GROWTH'));
    expect(tapped, isTrue);
  });
}
