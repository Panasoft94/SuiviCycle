class Cycle {
  final int? id;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? periodEndDate;
  final int? cycleLength;
  final DateTime? ovulationDate;
  final DateTime? expectedPeriod;
  final String? phase;
  final DateTime? createdAt;

  Cycle({
    this.id,
    required this.startDate,
    this.endDate,
    this.periodEndDate,
    this.cycleLength,
    this.ovulationDate,
    this.expectedPeriod,
    this.phase,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'period_end_date': periodEndDate?.toIso8601String(),
      'cycle_length': cycleLength,
      'ovulation_date': ovulationDate?.toIso8601String(),
      'expected_period': expectedPeriod?.toIso8601String(),
      'phase': phase,
    };
  }

  factory Cycle.fromMap(Map<String, dynamic> map) {
    return Cycle(
      id: map['id'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      periodEndDate: map['period_end_date'] != null ? DateTime.parse(map['period_end_date']) : null,
      cycleLength: map['cycle_length'],
      ovulationDate: map['ovulation_date'] != null ? DateTime.parse(map['ovulation_date']) : null,
      expectedPeriod: map['expected_period'] != null ? DateTime.parse(map['expected_period']) : null,
      phase: map['phase'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}
