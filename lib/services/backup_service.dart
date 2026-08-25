import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/med_plan_entry.dart';
import 'database_service.dart';
import 'notification_service.dart';

class BackupService {
  static Future<void> exportBackup() async {
    final medPlan = await DatabaseService.instance.getMedPlan();
    final List<Map<String, dynamic>> jsonList =
        medPlan.map((e) => e.toMap()).toList();

    final Map<String, dynamic> backupData = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'med_plan': jsonList,
    };

    final String jsonString =
        const JsonEncoder.withIndent('  ').convert(backupData);

    final tempDir = await getTemporaryDirectory();
    final String dateStr = DateTime.now().toIso8601String().split('T')[0];
    final file = File('${tempDir.path}/medication_backup_$dateStr.json');
    await file.writeAsString(jsonString);

    // Kompatibel mit allen share_plus Versionen
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Medikamenten-App Backup ($dateStr)',
    );
  }

  static Future<int> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return 0;
    }

    final file = File(result.files.single.path!);
    final String content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);

    if (!data.containsKey('med_plan')) {
      throw const FormatException('Ungültiges Backup-Format.');
    }

    final List<dynamic> list = data['med_plan'];
    int importedCount = 0;

    for (var item in list) {
      final entry = MedPlanEntry.fromMap(Map<String, dynamic>.from(item));
      final newEntry = MedPlanEntry(
        drugName: entry.drugName,
        dosage: entry.dosage,
        time: entry.time,
        instructions: entry.instructions,
        isActive: entry.isActive,
        isReminderActive: entry.isReminderActive,
        selectedDays: entry.selectedDays,
      );

      final newId = await DatabaseService.instance.insertMedPlanEntry(newEntry);

      final savedEntry = MedPlanEntry(
        id: newId,
        drugName: newEntry.drugName,
        dosage: newEntry.dosage,
        time: newEntry.time,
        instructions: newEntry.instructions,
        isActive: newEntry.isActive,
        isReminderActive: newEntry.isReminderActive,
        selectedDays: newEntry.selectedDays,
      );
      await NotificationService.instance.scheduleMedicationReminder(savedEntry);

      importedCount++;
    }

    return importedCount;
  }
}