import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/med_plan_entry.dart';
import 'database_service.dart';
import 'encrypted_backup_codec.dart';
import 'notification_service.dart';

class BackupService {
  static Future<void> exportBackup({required String password}) async {
    final medPlan = await DatabaseService.instance.getMedPlan();
    final backupData = <String, dynamic>{
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'med_plan': medPlan.map((entry) => entry.toMap()).toList(),
    };
    final encrypted = await EncryptedBackupCodec.encrypt(
      backupData,
      password: password,
    );

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final file = File('${tempDir.path}/medication_backup_$dateStr.medbackup');
    await file.writeAsString(encrypted, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Verschlüsseltes Medikamenten-Backup ($dateStr)',
    );
  }

  static Future<int> importBackup({
    required String password,
    bool allowLegacyPlaintext = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['medbackup', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      return 0;
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ungültiges Backup-Format.');
    }

    final Map<String, dynamic> data;
    if (decoded['format'] == EncryptedBackupCodec.formatName) {
      data = await EncryptedBackupCodec.decrypt(content, password: password);
    } else if (decoded['version'] == 1 && decoded.containsKey('med_plan')) {
      if (!allowLegacyPlaintext) {
        throw const FormatException(
          'Dieses alte Backup ist unverschlüsselt. Aktiviere beim Import ausdrücklich '
          'die Option für alte unverschlüsselte Backups, wenn du es trotzdem importieren willst.',
        );
      }
      data = decoded;
    } else {
      throw const FormatException(
        'Unbekanntes oder nicht unterstütztes Backup-Format.',
      );
    }

    if (data['med_plan'] is! List) {
      throw const FormatException('Das Backup enthält keinen gültigen Medikationsplan.');
    }

    // Validate the entire payload before changing the database so malformed
    // files cannot leave a partially imported plan.
    final entries = (data['med_plan'] as List).map((item) {
      if (item is! Map) {
        throw const FormatException('Ein Medikamenteneintrag ist beschädigt.');
      }
      final entry = MedPlanEntry.fromMap(Map<String, dynamic>.from(item));
      return MedPlanEntry(
        drugName: entry.drugName,
        dosage: entry.dosage,
        time: entry.time,
        instructions: entry.instructions,
        isActive: entry.isActive,
        isReminderActive: entry.isReminderActive,
        selectedDays: entry.selectedDays,
      );
    }).toList();

    for (final entry in entries) {
      final newId = await DatabaseService.instance.insertMedPlanEntry(entry);
      final savedEntry = MedPlanEntry(
        id: newId,
        drugName: entry.drugName,
        dosage: entry.dosage,
        time: entry.time,
        instructions: entry.instructions,
        isActive: entry.isActive,
        isReminderActive: entry.isReminderActive,
        selectedDays: entry.selectedDays,
      );
      await NotificationService.instance.scheduleMedicationReminder(savedEntry);
    }

    return entries.length;
  }
}
