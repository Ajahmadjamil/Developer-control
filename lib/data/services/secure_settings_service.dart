import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
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
}
