import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medication_app/models/med_plan_entry.dart';
import 'package:medication_app/models/user_profile.dart';
import 'package:medication_app/services/database_service.dart';
import 'package:medication_app/services/profile_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('migrates and encrypts local health data at rest', (tester) async {
    debugPrint('storage-test: started');
    final databasePath = p.join(
      await getDatabasesPath(),
      'medication_app.db',
    );

    // Simulate the existing plaintext database before the encrypted release.
    final legacyDatabase = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE med_plan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            drugName TEXT NOT NULL,
            dosage TEXT NOT NULL,
            time TEXT NOT NULL,
            instructions TEXT,
            isActive INTEGER NOT NULL DEFAULT 1,
            isReminderActive INTEGER NOT NULL DEFAULT 0,
            selectedDays TEXT NOT NULL,
            stockCount INTEGER NOT NULL DEFAULT 0,
            takenToday INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.insert('med_plan', {
          'drugName': 'Legacy CI',
          'dosage': '1',
          'time': '08:00',
          'instructions': '',
          'isActive': 1,
          'isReminderActive': 0,
          'selectedDays': '[1]',
          'stockCount': 0,
          'takenToday': 0,
        });
      },
    );
    await legacyDatabase.close();
    debugPrint('storage-test: legacy database ready');

    final database = await DatabaseService.instance.database;
    debugPrint('storage-test: encrypted database opened');
    final entry = MedPlanEntry(
      drugName: 'Encrypted CI',
      dosage: '1',
      time: '08:30',
      selectedDays: const [1],
    );
    await database.insert('med_plan', entry.toMap());
    final rows = await DatabaseService.instance.getMedPlan();
    expect(rows.map((row) => row.drugName), containsAll(['Legacy CI', 'Encrypted CI']));

    final headerHandle = await File(databasePath).open();
    final header = await headerHandle.read(16);
    await headerHandle.close();
    expect(ascii.decode(header, allowInvalid: true), isNot('SQLite format 3\u0000'));

    debugPrint('storage-test: database encryption verified');
    final legacyPrefs = await SharedPreferences.getInstance();
    await legacyPrefs.setString('user_name', 'Legacy Profile');
    await legacyPrefs.setString('user_insurance_num', 'LEGACY-123');
    final migratedProfile = await ProfileService.getProfile();
    expect(migratedProfile.name, 'Legacy Profile');
    expect(migratedProfile.insuranceNumber, 'LEGACY-123');
    expect(legacyPrefs.getString('user_name'), isNull);

    debugPrint('storage-test: legacy profile migration verified');
    const profile = UserProfile(
      name: 'Secure CI profile',
      insuranceNumber: 'TEST-123',
    );
    await ProfileService.saveProfile(profile);
    final restoredProfile = await ProfileService.getProfile();
    expect(restoredProfile.name, profile.name);
    expect(restoredProfile.insuranceNumber, profile.insuranceNumber);

    debugPrint('storage-test: secure profile write verified');
    await DatabaseService.instance.close();
    final reopened = await DatabaseService.instance.getMedPlan();
    expect(
      reopened.map((row) => row.drugName),
      containsAll(['Legacy CI', 'Encrypted CI']),
    );
    await DatabaseService.instance.close();
    debugPrint('storage-test: completed');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
