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
  final int stockCount;
  final bool takenToday;

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
  }) : selectedDays = (selectedDays ?? const [1, 2, 3, 4, 5, 6, 7])
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList()
          ..sort();

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
    var parsedDays = <int>[];
    final rawDays = map['selectedDays'];
    if (rawDays is String && rawDays.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDays);
        if (decoded is List) {
          parsedDays = decoded.whereType<int>()
              .where((day) => day >= 1 && day <= 7)
              .toSet()
              .toList()
            ..sort();
        }
      } on FormatException {
        // Older or damaged rows fall back to the historical daily schedule.
      }
    }
    if (parsedDays.isEmpty) {
      parsedDays = [1, 2, 3, 4, 5, 6, 7];
    }

    final rawId = map['id'];
    final rawStockCount = map['stockCount'];
    final active = map['isActive'] ?? 1;
    final reminderActive = map['isReminderActive'] ?? 1;
    final taken = map['takenToday'];

    return MedPlanEntry(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      drugName: map['drugName']?.toString() ?? '',
      dosage: map['dosage']?.toString() ?? '',
      time: map['time']?.toString() ?? '08:00',
      instructions: map['instructions']?.toString() ?? '',
      isActive: active == true || active == 1,
      isReminderActive: reminderActive == true || reminderActive == 1,
      selectedDays: parsedDays,
      stockCount: rawStockCount is int ? rawStockCount : int.tryParse(rawStockCount?.toString() ?? '') ?? 0,
      takenToday: taken == true || taken == 1,
    );
  }
}
