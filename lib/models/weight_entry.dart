import 'package:intl/intl.dart';

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

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    weight: (json['weight'] as num).toDouble(),
    note: json['note'] as String,
  );
}
