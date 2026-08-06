class QuickSettingsTileRequestResult {
  const QuickSettingsTileRequestResult({
    required this.supported,
    required this.message,
    this.resultCode,
  });

  final bool supported;
  final String message;
  final int? resultCode;
}
