class LaunchableApp {
  const LaunchableApp({
    required this.packageName,
    required this.label,
  });

  final String packageName;
  final String label;
}

class BankingGuardStatus {
  const BankingGuardStatus({
    required this.enabled,
    required this.hasUsageAccess,
    required this.packages,
    this.inBank = false,
    this.activePackage,
  });

  final bool enabled;
  final bool hasUsageAccess;
  final List<String> packages;
  final bool inBank;
  final String? activePackage;

  static const empty = BankingGuardStatus(
    enabled: false,
    hasUsageAccess: false,
    packages: [],
  );
}
