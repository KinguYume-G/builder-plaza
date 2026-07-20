// Basic smoke test for Builder Plaza.
//
// A fresh session (no stored token) must land on onboarding STEP 1 (GitHub
// connect), never on a blank or debug screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:builder_plaza/main.dart';

void main() {
  testWidgets('App boots to onboarding step 1', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BuilderPlazaApp());
    // Fixed pumps (not pumpAndSettle: the splash spinner animates forever).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('VERIFY YOUR WORK'), findsWidgets);
  });
}
