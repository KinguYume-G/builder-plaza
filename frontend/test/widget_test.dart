// Basic smoke test for Builder Plaza.
//
// Verifies the app boots and lands on the connectivity screen without throwing.
import 'package:flutter_test/flutter_test.dart';

import 'package:builder_plaza/main.dart';

void main() {
  testWidgets('App boots to connectivity screen', (tester) async {
    await tester.pumpWidget(const BuilderPlazaApp());
    // Pump once; network calls fail fast in the test environment but the
    // widget tree should build.
    await tester.pump();

    expect(find.text('BUILDER\nPLAZA'), findsOneWidget);
  });
}
