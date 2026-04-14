class AppSettings {
  final int id;
  final int defaultCycleLength;
  final bool notifyPeriod;
  final bool notifyOvulation;
  final String theme; // "light" or "dark"
  final bool autoLock;

  AppSettings({
    required this.id,
    this.defaultCycleLength = 28,
    this.notifyPeriod = true,
    this.notifyOvulation = true,
    this.theme = 'light',
    this.autoLock = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'default_cycle_length': defaultCycleLength,
      'notify_period': notifyPeriod ? 1 : 0, // Store bool as integer
      'notify_ovulation': notifyOvulation ? 1 : 0,
      'theme': theme,
      'auto_lock': autoLock ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'],
      defaultCycleLength: map['default_cycle_length'] ?? 28,
      notifyPeriod: map['notify_period'] == 1,
      notifyOvulation: map['notify_ovulation'] == 1,
      theme: map['theme'] ?? 'light',
      autoLock: map['auto_lock'] == 1,
    );
  }

  AppSettings copyWith({
    int? id,
    int? defaultCycleLength,
    bool? notifyPeriod,
    bool? notifyOvulation,
    String? theme,
    bool? autoLock,
  }) {
    return AppSettings(
      id: id ?? this.id,
      defaultCycleLength: defaultCycleLength ?? this.defaultCycleLength,
      notifyPeriod: notifyPeriod ?? this.notifyPeriod,
      notifyOvulation: notifyOvulation ?? this.notifyOvulation,
      theme: theme ?? this.theme,
      autoLock: autoLock ?? this.autoLock,
    );
  }
}
