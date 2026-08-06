/// App-wide constants.
abstract final class AppConstants {
  static const appName = 'Developer Control';

  static const logoAsset = 'assets/logo/logo.png';

  static const methodChannel =
      'com.ahmadjamil.developercontrol/secure_settings';

  static const adbGrantCommand =
      'adb shell pm grant com.ahmadjamil.developercontrol '
      'android.permission.WRITE_SECURE_SETTINGS';
}
