import 'package:flutter/foundation.dart';

import '../data/models/banking_guard_status.dart';
import '../data/services/banking_guard_service.dart';
import '../data/services/preferences_service.dart';

/// Separate controller for Banking Guard — independent of Dev Mode schedule.
class BankingGuardController extends ChangeNotifier {
  BankingGuardController({
    required BankingGuardService service,
    required PreferencesService prefs,
  })  : _service = service,
        _prefs = prefs;

  final BankingGuardService _service;
  final PreferencesService _prefs;

  bool _loading = true;
  bool _busy = false;
  BankingGuardStatus _status = BankingGuardStatus.empty;
  String? _message;

  bool get loading => _loading;
  bool get busy => _busy;
  BankingGuardStatus get status => _status;
  bool get enabled => _status.enabled;
  bool get hasUsageAccess => _status.hasUsageAccess;
  List<String> get packages => _status.packages;
  String? get message => _message;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _status = await _service.getStatus();
    // Mirror packages into Flutter prefs for UI convenience only.
    await _prefs.setBankingPackages(_status.packages);
    _loading = false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final result = await _service.setEnabled(value);
      await refresh();
      if (result.message.isNotEmpty) {
        _emit(result.message);
      }
      if (!result.ok && value) {
        // Keep switch visually off when enable failed.
        _status = await _service.getStatus();
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> savePackages(List<String> packages) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _status = await _service.setPackages(packages);
      await _prefs.setBankingPackages(packages);
      _emit(
        packages.isEmpty
            ? 'No banking apps selected'
            : '${packages.length} app(s) selected',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> openUsageAccess() async {
    await _service.openUsageAccessSettings();
    _emit('Find Developer Control and allow Usage Access');
  }

  void clearMessage() {
    _message = null;
  }

  void _emit(String message) {
    _message = message;
    notifyListeners();
  }
}
