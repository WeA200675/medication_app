import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app/models/med_plan_entry.dart';

void main() {
  group('MedPlanEntry', () {
    test('round-trips selected weekdays and medication state', () {
      final original = MedPlanEntry(
        id: 42,
        drugName: 'Beispiel',
        dosage: '1 Tablette',
        time: '08:30',
        instructions: 'Nach dem Frühstück',
        isActive: true,
        isReminderActive: true,
        selectedDays: const [1, 3, 5],
        stockCount: 12,
        takenToday: true,
      );

      final restored = MedPlanEntry.fromMap(original.toMap());

      expect(restored.id, 42);
      expect(restored.drugName, 'Beispiel');
      expect(restored.selectedDays, [1, 3, 5]);
      expect(restored.isReminderActive, isTrue);
      expect(restored.stockCount, 12);
      expect(restored.takenToday, isTrue);
    });

    test('normalizes invalid stored weekdays and tolerates legacy rows', () {
      final restored = MedPlanEntry.fromMap({
        'id': '7',
        'drugName': 'Altbestand',
        'dosage': '',
        'time': '09:00',
        'selectedDays': '[1, 1, 8, "invalid"]',
        'stockCount': '3',
      });

      expect(restored.id, 7);
      expect(restored.selectedDays, [1]);
      expect(restored.isActive, isTrue);
      expect(restored.isReminderActive, isTrue);
      expect(restored.stockCount, 3);
    });

    test('falls back to all days for a malformed legacy schedule', () {
      final restored = MedPlanEntry.fromMap({
        'drugName': 'Altbestand',
        'selectedDays': 'not-json',
      });

      expect(restored.selectedDays, [1, 2, 3, 4, 5, 6, 7]);
    });
  });
}
