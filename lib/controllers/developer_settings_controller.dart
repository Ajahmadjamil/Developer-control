import 'package:flutter/foundation.dart';

import '../data/services/preferences_service.dart';
import '../data/services/secure_settings_service.dart';

/// Controls Developer Options / USB Debugging toggles and related UI prefs.
class DeveloperSettingsController extends ChangeNotifier {
  DeveloperSettingsController({
    required SecureSettingsService settings,
    required PreferencesService prefs,
  })  : _settings = settings,
        _prefs = prefs;

  final SecureSettingsService _settings;
  final PreferencesService _prefs;

  bool _loading = true;
  bool _busy = false;
  bool _hasSecurePermission = false;
  bool _developerOptionsEnabled = false;
  bool _usbDebuggingEnabled = false;
  bool _combineToggles = false;
  String? _message;

  bool get loading => _loading;
  bool get busy => _busy;
  bool get hasSecurePermission => _hasSecurePermission;
  bool get developerOptionsEnabled => _developerOptionsEnabled;
  bool get usbDebuggingEnabled => _usbDebuggingEnabled;
  bool get combineToggles => _combineToggles;
  bool get combinedActive =>
      _developerOptionsEnabled && _usbDebuggingEnabled;
  String? get message => _message;

  Future<void> init() async {
    _combineToggles = await _prefs.isCombineTogglesEnabled();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    final hasPerm = await _settings.hasWriteSecureSettings();
    final devOpts = await _settings.isDeveloperOptionsEnabled();
    final adb = await _settings.isUsbDebuggingEnabled();

    _hasSecurePermission = hasPerm;
    _developerOptionsEnabled = devOpts;
    _usbDebuggingEnabled = adb;
    _loading = false;
    notifyListeners();
  }

  Future<void> setCombineToggles(bool enabled) async {
    _combineToggles = enabled;
    notifyListeners();
    await _prefs.setCombineTogglesEnabled(enabled: enabled);
  }

  Future<void> addQuickSettingsTile() async {
    final result = await _settings.requestAddQuickSettingsTile();
    _emit(result.message);
  }

  Future<void> setCombinedMode(bool enabled) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();

    try {
      final hasPerm = await _settings.hasWriteSecureSettings();

      if (hasPerm) {
        if (enabled) {
          final ok = await _settings.setDeveloperOptionsEnabled(enabled: true) &&
              await _settings.setUsbDebuggingEnabled(enabled: true);
          if (ok) {
            await refreshStatus();
            _emit('Developer Options + USB Debugging turned ON');
            return;
          }
        } else {
          final ok = await _settings.setUsbDebuggingEnabled(enabled: false) &&
              await _settings.setDeveloperOptionsEnabled(enabled: false);
          if (ok) {
            await refreshStatus();
            _emit('Developer Options + USB Debugging turned OFF');
            return;
          }
        }
      }

      if (enabled) {
        if (!_developerOptionsEnabled) {
          await _settings.openDeviceInfoSettings();
          _emit('Tap Build number 7 times, then enable USB debugging');
        } else {
          await _settings.openDeveloperOptionsSettings();
          _emit('Enable USB debugging on the Developer options screen');
        }
      } else {
        await _settings.openDeveloperOptionsSettings();
        _emit('Turn both options off on the Developer options screen');
      }
    } finally {
      _busy = false;
      await refreshStatus();
    }
  }

  Future<void> setDeveloperOptions(bool enabled) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();

    try {
      final hasPerm = await _settings.hasWriteSecureSettings();

      if (hasPerm) {
        if (!enabled && _usbDebuggingEnabled) {
          await _settings.setUsbDebuggingEnabled(enabled: false);
        }
        final ok =
            await _settings.setDeveloperOptionsEnabled(enabled: enabled);
        if (ok) {
          await refreshStatus();
          _emit(
            enabled
                ? 'Developer Options turned ON'
                : 'Developer Options turned OFF',
          );
          return;
        }
      }

      if (enabled) {
        await _settings.openDeviceInfoSettings();
        _emit('Tap Build number 7 times on the About phone screen');
      } else {
        await _settings.openDeveloperOptionsSettings();
        _emit('Turn off Developer options on the Settings screen');
      }
    } finally {
      _busy = false;
      await refreshStatus();
    }
  }

  Future<void> setUsbDebugging(bool enabled) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();

    try {
      final hasPerm = await _settings.hasWriteSecureSettings();

      if (hasPerm) {
        final ok = await _settings.setUsbDebuggingEnabled(enabled: enabled);
        if (ok) {
          await refreshStatus();
          _emit(
            enabled
                ? 'USB Debugging turned ON'
                : 'USB Debugging turned OFF',
          );
          return;
        }
      }

      if (!_developerOptionsEnabled) {
        await _settings.openDeviceInfoSettings();
        _emit(
          'Enable Developer Options first (tap Build number), then try again',
        );
        return;
      }

      await _settings.openDeveloperOptionsSettings();
      _emit('Toggle USB debugging on the Developer options screen');
    } finally {
      _busy = false;
      await refreshStatus();
    }
  }

  void clearMessage() {
    _message = null;
  }

  void _emit(String message) {
    _message = message;
    notifyListeners();
  }
}
