import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../models/enable_tap_to_lock_result.dart';

/// Dart bridge for Tap to Lock (Device Admin + pin widget).
class LockWidgetService {
  LockWidgetService();

  static const MethodChannel _channel = MethodChannel(
    AppConstants.methodChannel,
  );

  Future<bool> hasLockPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasLockPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// One call: activate Device Admin if needed, then show the pin-widget dialog.
  Future<EnableTapToLockResult> enableTapToLock() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'enableTapToLock',
      );
      if (raw == null) {
        return const EnableTapToLockResult(
          success: false,
          message: 'Could not enable Tap to Lock.',
        );
      }
      return EnableTapToLockResult(
        success: raw['success'] as bool? ?? false,
        pinShown: raw['pinShown'] as bool? ?? false,
        message: raw['message'] as String? ?? '',
      );
    } on MissingPluginException {
      return const EnableTapToLockResult(
        success: false,
        message: 'Native code outdated — fully stop the app and rebuild.',
      );
    } on PlatformException catch (e) {
      return EnableTapToLockResult(
        success: false,
        message: e.message ?? 'Could not enable Tap to Lock',
      );
    }
  }
}
