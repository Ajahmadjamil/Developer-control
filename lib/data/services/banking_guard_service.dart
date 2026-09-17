import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../models/banking_guard_status.dart';

/// Separate bridge for Banking Guard (does not touch schedule/lock APIs).
class BankingGuardService {
  BankingGuardService();

  static const MethodChannel _channel = MethodChannel(
    AppConstants.methodChannel,
  );

  Future<BankingGuardStatus> getStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getBankingGuard',
      );
      if (raw == null) return BankingGuardStatus.empty;
      final pkgs = (raw['packages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      return BankingGuardStatus(
        enabled: raw['enabled'] as bool? ?? false,
        hasUsageAccess: raw['hasUsageAccess'] as bool? ?? false,
        packages: pkgs,
        inBank: raw['inBank'] as bool? ?? false,
        activePackage: raw['activePackage'] as String?,
      );
    } on MissingPluginException {
      return BankingGuardStatus.empty;
    } on PlatformException {
      return BankingGuardStatus.empty;
    }
  }

  Future<({bool ok, String message, bool needsUsageAccess})> setEnabled(
    bool enabled,
  ) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setBankingGuardEnabled',
        {'enabled': enabled},
      );
      if (raw == null) {
        return (ok: false, message: 'Could not update Banking Guard', needsUsageAccess: false);
      }
      return (
        ok: raw['ok'] as bool? ?? false,
        message: raw['message'] as String? ?? '',
        needsUsageAccess: raw['needsUsageAccess'] as bool? ?? false,
      );
    } on MissingPluginException {
      return (
        ok: false,
        message: 'Native code outdated — fully stop and rebuild.',
        needsUsageAccess: false,
      );
    } on PlatformException catch (e) {
      return (
        ok: false,
        message: e.message ?? 'Failed',
        needsUsageAccess: false,
      );
    }
  }

  Future<BankingGuardStatus> setPackages(List<String> packages) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setBankingGuardPackages',
        {'packages': packages},
      );
      if (raw == null) return BankingGuardStatus.empty;
      final pkgs = (raw['packages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          packages;
      return BankingGuardStatus(
        enabled: raw['enabled'] as bool? ?? false,
        hasUsageAccess: raw['hasUsageAccess'] as bool? ?? false,
        packages: pkgs,
        inBank: raw['inBank'] as bool? ?? false,
        activePackage: raw['activePackage'] as String?,
      );
    } on PlatformException {
      return BankingGuardStatus.empty;
    }
  }

  Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod<bool>('openUsageAccessSettings');
  }

  Future<List<LaunchableApp>> listLaunchableApps() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listLaunchableApps');
      if (raw == null) return const [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return LaunchableApp(
          packageName: m['packageName'] as String? ?? '',
          label: m['label'] as String? ?? '',
        );
      }).where((a) => a.packageName.isNotEmpty).toList();
    } on PlatformException {
      return const [];
    }
  }
}
