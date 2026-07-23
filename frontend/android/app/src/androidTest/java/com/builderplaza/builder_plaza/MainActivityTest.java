package com.builderplaza.builder_plaza;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/**
 * Instrumentation harness that lets integration_test/e2e_test.dart run as a
 * standard Android instrumented test, which is the only form a real-device
 * cloud (AWS Device Farm, Firebase Test Lab) knows how to execute.
 *
 * Build the pair with:
 *   flutter build apk --debug --target=integration_test/e2e_test.dart
 *   (cd android && ./gradlew app:assembleAndroidTest)
 *
 * See .github/scripts/device-farm.sh, which does exactly that before
 * uploading.
 */
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  @Rule
  public ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<>(MainActivity.class, true, false);
}
