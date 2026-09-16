class EnableTapToLockResult {
  const EnableTapToLockResult({
    required this.success,
    this.pinShown = false,
    this.message = '',
  });

  final bool success;
  final bool pinShown;
  final String message;
}
