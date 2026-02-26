class Hydration {
  final int? id;
  final DateTime date; // Store as ISO8601 string in DB
  final double amount; // Amount in Liters
  final int goalMet; // 0 or 1

  Hydration({
    this.id,
    required this.date,
    required this.amount,
    this.goalMet = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'goal_met': goalMet,
    };
  }

  factory Hydration.fromMap(Map<String, dynamic> map) {
    return Hydration(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'],
      goalMet: map['goal_met'] ?? 0,
    );
  }
}

