import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const completedKey = 'onboarding_complete_v1';
  static Future<bool> isComplete() async =>
      (await SharedPreferences.getInstance()).getBool(completedKey) ?? false;
  static Future<void> complete() async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      completedKey,
      true,
    );
    if (!saved) throw StateError('Unable to save onboarding progress.');
  }
}
