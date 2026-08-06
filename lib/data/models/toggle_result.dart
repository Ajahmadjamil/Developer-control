/// Result of a USB debugging toggle attempt via the native layer.
class ToggleResult {
  const ToggleResult({required this.success, required this.enabled});

  final bool success;
  final bool enabled;
}
