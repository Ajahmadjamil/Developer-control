import 'package:flutter/foundation.dart';

import '../data/services/preferences_service.dart';
import '../data/services/secure_settings_service.dart';

/// Owns first-launch / onboarding navigation state.
class AppController extends ChangeNotifier {
  AppController({
    required SecureSettingsService settings,
    required PreferencesService prefs,
  })  : _settings = settings,
        _prefs = prefs;

  final SecureSettingsService _settings;
  final PreferencesService _prefs;

  bool _ready = false;
  bool _showOnboarding = false;
  bool _hasSecurePermission = false;
  bool _checkingPermission = false;
  String? _message;

  bool get ready => _ready;
  bool get showOnboarding => _showOnboarding;
  bool get hasSecurePermission => _hasSecurePermission;
  bool get checkingPermission => _checkingPermission;
  String? get message => _message;

  Future<void> bootstrap() async {
    final onboarded = await _prefs.isOnboardingCompleted();
    final hasPerm = await _settings.hasWriteSecureSettings();
    _hasSecurePermission = hasPerm;
    _showOnboarding = !onboarded;
    _ready = true;
    notifyListeners();
  }

  Future<bool> recheckPermission() async {
    _checkingPermission = true;
    notifyListeners();

    final granted = await _settings.hasWriteSecureSettings();
    _hasSecurePermission = granted;
    _checkingPermission = false;
    _message = granted
        ? 'WRITE_SECURE_SETTINGS granted — 1-click is ready'
        : 'Permission still missing. Run the ADB command, then retry.';
    notifyListeners();
    return granted;
  }

  Future<void> finishOnboarding() async {
    await _prefs.setOnboardingCompleted(completed: true);
    _showOnboarding = false;
    notifyListeners();
  }

  void openSetupAgain() {
    _showOnboarding = true;
    notifyListeners();
  }

  void clearMessage() {
    _message = null;
  }
}
