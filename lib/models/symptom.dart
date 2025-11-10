class Symptom {
  final int? id;
  final int cycleId;
  final DateTime date;
  final String? mood;
  final int? painLevel;
  final int? energyLevel;
  final int? libidoLevel;
  final String? notes;

  Symptom({
    this.id,
    required this.cycleId,
    required this.date,
    this.mood,
    this.painLevel,
    this.energyLevel,
    this.libidoLevel,
    this.notes,
  });

  // Convert a Symptom into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycle_id': cycleId,
      'date': date.toIso8601String(),
      'mood': mood,
      'pain_level': painLevel,
      'energy_level': energyLevel,
      'libido_level': libidoLevel,
      'notes': notes,
    };
  }

  // Convert a Map into a Symptom.
  factory Symptom.fromMap(Map<String, dynamic> map) {
    return Symptom(
      id: map['id'],
      cycleId: map['cycle_id'],
      date: DateTime.parse(map['date']),
      mood: map['mood'],
      painLevel: map['pain_level'],
      energyLevel: map['energy_level'],
      libidoLevel: map['libido_level'],
      notes: map['notes'],
    );
  }
}
