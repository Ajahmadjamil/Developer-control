import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/dev_mode_schedule.dart';
import '../data/services/preferences_service.dart';
import '../data/services/secure_settings_service.dart';

/// Controls Developer Options / USB Debugging toggles, prefs, and local schedule.
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
  DevModeSchedule _schedule = DevModeSchedule.defaults;
  String? _message;

  bool get loading => _loading;
  bool get busy => _busy;
  bool get hasSecurePermission => _hasSecurePermission;
  bool get developerOptionsEnabled => _developerOptionsEnabled;
  bool get usbDebuggingEnabled => _usbDebuggingEnabled;
  bool get combineToggles => _combineToggles;
  bool get combinedActive =>
      _developerOptionsEnabled && _usbDebuggingEnabled;
  DevModeSchedule get schedule => _schedule;
  String? get message => _message;

  Future<void> init() async {
    _combineToggles = await _prefs.isCombineTogglesEnabled();
    final enabled = await _prefs.isDevScheduleEnabled();
    final start = await _prefs.getDevScheduleStartMinutes();
    final end = await _prefs.getDevScheduleEndMinutes();
    _schedule = DevModeSchedule(
      enabled: enabled,
      startMinutes: start,
      endMinutes: end,
    );

    // Push saved schedule into native AlarmManager, then read live status.
    await _settings.syncDevModeSchedule(
      enabled: enabled,
      startMinutes: start,
      endMinutes: end,
      applyNow: false,
    );
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    final hasPerm = await _settings.hasWriteSecureSettings();
    final devOpts = await _settings.isDeveloperOptionsEnabled();
    final adb = await _settings.isUsbDebuggingEnabled();
    final nativeSchedule = await _settings.getDevModeSchedule();

    _hasSecurePermission = hasPerm;
    _developerOptionsEnabled = devOpts;
    _usbDebuggingEnabled = adb;
    _schedule = nativeSchedule;
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

  Future<void> setScheduleEnabled(bool enabled) async {
    if (_busy) return;
    if (enabled && !_hasSecurePermission) {
      _emit('Grant WRITE_SECURE_SETTINGS via ADB first — schedule needs 1-click mode');
      return;
    }
    if (enabled && _schedule.startMinutes == _schedule.endMinutes) {
      _emit('Pick different start and end times');
      return;
    }

    _busy = true;
    notifyListeners();
    try {
      final result = await _settings.syncDevModeSchedule(
        enabled: enabled,
        startMinutes: _schedule.startMinutes,
        endMinutes: _schedule.endMinutes,
        applyNow: enabled,
      );
      if (!result.ok) {
        _emit(result.message.isEmpty ? 'Could not update schedule' : result.message);
        return;
      }
      _schedule = result.schedule;
      await _prefs.setDevSchedule(
        enabled: _schedule.enabled,
        startMinutes: _schedule.startMinutes,
        endMinutes: _schedule.endMinutes,
      );
      await refreshStatus();
      if (enabled) {
        _emit(
          _schedule.insideWindow
              ? 'Schedule on — Dev Mode ON until ${_formatTime(_schedule.endMinutes)} (manual still works)'
              : 'Schedule on — Dev Mode OFF until ${_formatTime(_schedule.startMinutes)} (manual still works)',
        );
      } else {
        _emit('Schedule off — Dev Mode stays as you left it');
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setScheduleStart(TimeOfDay time) async {
    await _updateScheduleTimes(
      startMinutes: time.hour * 60 + time.minute,
      endMinutes: _schedule.endMinutes,
    );
  }

  Future<void> setScheduleEnd(TimeOfDay time) async {
    await _updateScheduleTimes(
      startMinutes: _schedule.startMinutes,
      endMinutes: time.hour * 60 + time.minute,
    );
  }

  Future<void> _updateScheduleTimes({
    required int startMinutes,
    required int endMinutes,
  }) async {
    if (_busy) return;
    if (startMinutes == endMinutes) {
      _emit('Start and end time must be different');
      return;
    }

    _busy = true;
    notifyListeners();
    try {
      final enabled = _schedule.enabled;
      final result = await _settings.syncDevModeSchedule(
        enabled: enabled,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        applyNow: enabled,
      );
      if (!result.ok) {
        _emit(result.message.isEmpty ? 'Could not update times' : result.message);
        return;
      }
      _schedule = result.schedule;
      await _prefs.setDevSchedule(
        enabled: _schedule.enabled,
        startMinutes: _schedule.startMinutes,
        endMinutes: _schedule.endMinutes,
      );
      await refreshStatus();
      _emit('Window set to ${_schedule.windowLabel}');
    } finally {
      _busy = false;
      notifyListeners();
    }
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

  String _formatTime(int totalMinutes) {
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
