import 'package:flutter/foundation.dart';

import '../data/services/lock_widget_service.dart';
import '../data/services/preferences_service.dart';

/// One-toggle flow: Device Admin → pin transparent home widget.
class LockWidgetController extends ChangeNotifier {
  LockWidgetController({
    required LockWidgetService lockWidget,
    required PreferencesService prefs,
  })  : _lockWidget = lockWidget,
        _prefs = prefs;

  final LockWidgetService _lockWidget;
  final PreferencesService _prefs;

  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _hasPermission = false;
  String? _message;

  bool get loading => _loading;
  bool get busy => _busy;
  bool get enabled => _enabled;
  bool get hasPermission => _hasPermission;
  String? get message => _message;

  Future<void> init() async {
    _enabled = await _prefs.isLockWidgetEnabled();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    _hasPermission = await _lockWidget.hasLockPermission();

    if (_enabled && !_hasPermission) {
      _enabled = false;
      await _prefs.setLockWidgetEnabled(enabled: false);
    }

    _loading = false;
    notifyListeners();
  }

  /// ON → native handles Device Admin + pin dialog.
  /// OFF → remember preference only.
  Future<void> setEnabled(bool value) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();

    try {
      if (!value) {
        _enabled = false;
        await _prefs.setLockWidgetEnabled(enabled: false);
        // Quiet off — no snackbar spam.
        return;
      }

      _enabled = true;
      notifyListeners();

      final result = await _lockWidget.enableTapToLock();

      if (!result.success) {
        _enabled = false;
        _hasPermission = false;
        await _prefs.setLockWidgetEnabled(enabled: false);
        if (result.message.isNotEmpty) {
          _emit(result.message);
        }
        return;
      }

      _hasPermission = true;
      _enabled = true;
      await _prefs.setLockWidgetEnabled(enabled: true);

      // System pin dialog is the feedback — only speak if pin could not show.
      if (result.message.isNotEmpty) {
        _emit(result.message);
      }
    } finally {
      _busy = false;
      notifyListeners();
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
