import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding and UI preferences.
class PreferencesService {
  PreferencesService();

  static const _onboardedKey = 'onboarding_completed';
  static const _combineTogglesKey = 'combine_toggles';

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboardingCompleted({required bool completed}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, completed);
  }

  Future<bool> isCombineTogglesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_combineTogglesKey) ?? false;
  }

  Future<void> setCombineTogglesEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_combineTogglesKey, enabled);
  }
}
