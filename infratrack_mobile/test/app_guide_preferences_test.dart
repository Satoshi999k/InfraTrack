import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'first-launch guide is shown once and stays dismissed after updates',
    () async {
      SharedPreferences.setMockInitialValues({});

      expect(await AppGuidePreferences.shouldShowFirstLaunchGuide(), isTrue);

      await AppGuidePreferences.markGuideCompleted();

      expect(await AppGuidePreferences.shouldShowFirstLaunchGuide(), isFalse);
    },
  );
}
