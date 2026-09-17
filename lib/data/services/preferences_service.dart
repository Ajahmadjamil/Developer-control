import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding and UI preferences.
class PreferencesService {
  PreferencesService();

  static const _onboardedKey = 'onboarding_completed';
  static const _combineTogglesKey = 'combine_toggles';
  static const _lockWidgetKey = 'lock_widget_enabled';
  static const _scheduleEnabledKey = 'dev_schedule_enabled';
  static const _scheduleStartKey = 'dev_schedule_start_minutes';
  static const _scheduleEndKey = 'dev_schedule_end_minutes';
  static const _bankingPackagesKey = 'banking_guard_packages';

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

  Future<bool> isLockWidgetEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockWidgetKey) ?? false;
  }

  Future<void> setLockWidgetEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockWidgetKey, enabled);
  }

  Future<bool> isDevScheduleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduleEnabledKey) ?? false;
  }

  Future<int> getDevScheduleStartMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scheduleStartKey) ?? 9 * 60;
  }

  Future<int> getDevScheduleEndMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scheduleEndKey) ?? 18 * 60;
  }

  Future<void> setDevSchedule({
    required bool enabled,
    required int startMinutes,
    required int endMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduleEnabledKey, enabled);
    await prefs.setInt(_scheduleStartKey, startMinutes);
    await prefs.setInt(_scheduleEndKey, endMinutes);
  }

  Future<List<String>> getBankingPackages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_bankingPackagesKey) ?? const [];
  }

  Future<void> setBankingPackages(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_bankingPackagesKey, packages);
  }
}
