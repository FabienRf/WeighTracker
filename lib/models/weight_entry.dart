import 'package:intl/intl.dart';

// Represents a weigh-in entry (id, date, weight, note).
// Role: serialize to/from JSON for local storage.
class WeightEntry {
  final int id;
  final DateTime date;
  final double weight;
  final String note;

  WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'weight': weight,
    'note': note,
  };

  // Construit une instance depuis une map JSON.
  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    weight: (json['weight'] as num).toDouble(),
    note: json['note'] as String,
  );
}
