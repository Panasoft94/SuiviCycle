class Note {
  final int? id;
  final DateTime date;
  final String content;

  Note({this.id, required this.date, required this.content});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'content': content,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      date: DateTime.parse(map['date']),
      content: map['content'],
    );
  }
}
