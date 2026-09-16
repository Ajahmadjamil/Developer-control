import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../models/dev_mode_schedule.dart';
import '../models/quick_settings_tile_result.dart';
import '../models/toggle_result.dart';

/// Dart bridge to [MainActivity] MethodChannel for Settings.Global access
/// and system Settings deep-links.
class SecureSettingsService {
  SecureSettingsService();

  static const MethodChannel _channel = MethodChannel(
    AppConstants.methodChannel,
  );

  static const String adbGrantCommand = AppConstants.adbGrantCommand;

  Future<bool> hasWriteSecureSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasWriteSecureSettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isDeveloperOptionsEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isDeveloperOptionsEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isUsbDebuggingEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isUsbDebuggingEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setDeveloperOptionsEnabled({required bool enabled}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setDeveloperOptionsEnabled',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setUsbDebuggingEnabled({required bool enabled}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setUsbDebuggingEnabled',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<ToggleResult> toggleUsbDebugging() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'toggleUsbDebugging',
      );
      if (raw == null) {
        return const ToggleResult(success: false, enabled: false);
      }
      return ToggleResult(
        success: raw['success'] as bool? ?? false,
        enabled: raw['enabled'] as bool? ?? false,
      );
    } on PlatformException {
      return const ToggleResult(success: false, enabled: false);
    }
  }

  Future<void> openDeviceInfoSettings() async {
    await _channel.invokeMethod<bool>('openDeviceInfoSettings');
  }

  Future<void> openDeveloperOptionsSettings() async {
    await _channel.invokeMethod<bool>('openDeveloperOptionsSettings');
  }

  Future<QuickSettingsTileRequestResult> requestAddQuickSettingsTile() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'requestAddQuickSettingsTile',
      );
      if (raw == null) {
        return const QuickSettingsTileRequestResult(
          supported: false,
          message: 'Unable to request Quick Settings tile.',
        );
      }
      return QuickSettingsTileRequestResult(
        supported: raw['supported'] as bool? ?? false,
        message: raw['message'] as String? ?? '',
        resultCode: raw['resultCode'] as int?,
      );
    } on PlatformException catch (e) {
      return QuickSettingsTileRequestResult(
        supported: false,
        message: e.message ?? 'Failed to add Quick Settings tile',
      );
    }
  }

  Future<DevModeSchedule> getDevModeSchedule() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDevModeSchedule',
      );
      if (raw == null) return DevModeSchedule.defaults;
      return DevModeSchedule(
        enabled: raw['enabled'] as bool? ?? false,
        startMinutes: raw['startMinutes'] as int? ?? 9 * 60,
        endMinutes: raw['endMinutes'] as int? ?? 18 * 60,
        insideWindow: raw['insideWindow'] as bool? ?? false,
        canScheduleExact: raw['canScheduleExact'] as bool? ?? true,
      );
    } on MissingPluginException {
      return DevModeSchedule.defaults;
    } on PlatformException {
      return DevModeSchedule.defaults;
    }
  }

  /// Arms local alarms. [applyNow] applies expected on/off once; after that
  /// manual toggles stick until the next scheduled alarm.
  Future<({bool ok, String message, DevModeSchedule schedule})>
      syncDevModeSchedule({
    required bool enabled,
    required int startMinutes,
    required int endMinutes,
    bool applyNow = true,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'syncDevModeSchedule',
        {
          'enabled': enabled,
          'startMinutes': startMinutes,
          'endMinutes': endMinutes,
          'applyNow': applyNow,
        },
      );
      if (raw == null) {
        return (
          ok: false,
          message: 'Could not sync schedule',
          schedule: DevModeSchedule(
            enabled: enabled,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
          ),
        );
      }
      final schedule = DevModeSchedule(
        enabled: raw['enabled'] as bool? ?? enabled,
        startMinutes: raw['startMinutes'] as int? ?? startMinutes,
        endMinutes: raw['endMinutes'] as int? ?? endMinutes,
        insideWindow: raw['insideWindow'] as bool? ?? false,
      );
      return (
        ok: raw['ok'] as bool? ?? false,
        message: raw['message'] as String? ?? '',
        schedule: schedule,
      );
    } on MissingPluginException {
      return (
        ok: false,
        message: 'Native code outdated — fully stop and rebuild the app.',
        schedule: DevModeSchedule(
          enabled: enabled,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
        ),
      );
    } on PlatformException catch (e) {
      return (
        ok: false,
        message: e.message ?? 'Failed to sync schedule',
        schedule: DevModeSchedule(
          enabled: enabled,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
        ),
      );
    }
  }
}
