import 'dart:convert';

class MedPlanEntry {
  final int? id;
  final String drugName;
  final String dosage;
  final String time;
  final String instructions;
  final bool isActive;
  final bool isReminderActive;
  final List<int> selectedDays; // 1 = Montag, 7 = Sonntag
  final int stockCount; // Aktueller Vorrat in Stück
  final bool takenToday; // Ob heute bereits eingenommen

  MedPlanEntry({
    this.id,
    required this.drugName,
    required this.dosage,
    required this.time,
    this.instructions = '',
    this.isActive = true,
    this.isReminderActive = true,
    List<int>? selectedDays,
    this.stockCount = 0,
    this.takenToday = false,
  }) : selectedDays = selectedDays ?? [1, 2, 3, 4, 5, 6, 7];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drugName': drugName,
      'dosage': dosage,
      'time': time,
      'instructions': instructions,
      'isActive': isActive ? 1 : 0,
      'isReminderActive': isReminderActive ? 1 : 0,
      'selectedDays': jsonEncode(selectedDays),
      'stockCount': stockCount,
      'takenToday': takenToday ? 1 : 0,
    };
  }

  factory MedPlanEntry.fromMap(Map<String, dynamic> map) {
    List<int> parsedDays = [1, 2, 3, 4, 5, 6, 7];
    if (map['selectedDays'] != null) {
      try {
        final decoded = jsonDecode(map['selectedDays']);
        if (decoded is List) {
          parsedDays = decoded.map((e) => e as int).toList();
        }
      } catch (_) {}
    }

    return MedPlanEntry(
      id: map['id'] as int?,
      drugName: map['drugName'] ?? '',
      dosage: map['dosage'] ?? '',
      time: map['time'] ?? '08:00',
      instructions: map['instructions'] ?? '',
      isActive: (map['isActive'] ?? 1) == 1,
      isReminderActive: (map['isReminderActive'] ?? 1) == 1,
      selectedDays: parsedDays,
      stockCount: map['stockCount'] ?? 0,
      takenToday: (map['takenToday'] ?? 0) == 1,
    );
  }
}