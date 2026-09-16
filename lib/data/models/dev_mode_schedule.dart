class DevModeSchedule {
  const DevModeSchedule({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    this.insideWindow = false,
    this.canScheduleExact = true,
  });

  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final bool insideWindow;
  final bool canScheduleExact;

  int get startHour => startMinutes ~/ 60;
  int get startMinute => startMinutes % 60;
  int get endHour => endMinutes ~/ 60;
  int get endMinute => endMinutes % 60;

  String get windowLabel {
    String fmt(int total) {
      final h = total ~/ 60;
      final m = total % 60;
      final hh = h.toString().padLeft(2, '0');
      final mm = m.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    return '${fmt(startMinutes)} → ${fmt(endMinutes)}';
  }

  DevModeSchedule copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    bool? insideWindow,
    bool? canScheduleExact,
  }) {
    return DevModeSchedule(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      insideWindow: insideWindow ?? this.insideWindow,
      canScheduleExact: canScheduleExact ?? this.canScheduleExact,
    );
  }

  static const defaults = DevModeSchedule(
    enabled: false,
    startMinutes: 9 * 60,
    endMinutes: 18 * 60,
  );
}
