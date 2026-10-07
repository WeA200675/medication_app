import 'dart:convert';
import 'dart:io';

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

  testWidgets('encrypts local database and profile at rest', (tester) async {
    final database = await DatabaseService.instance.database;
    final entry = MedPlanEntry(
      drugName: 'CI Test',
      dosage: '1',
      time: '08:00',
      selectedDays: const [1],
    );
    final id = await database.insert('med_plan', entry.toMap());
    final rows = await database.query(
      'med_plan',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(rows.single['drugName'], 'CI Test');

    final databasePath = p.join(
      await getDatabasesPath(),
      'medication_app.db',
    );
    final headerHandle = await File(databasePath).open();
    final header = await headerHandle.read(16);
    await headerHandle.close();
    expect(ascii.decode(header, allowInvalid: true), isNot('SQLite format 3\\u0000'));

    const profile = UserProfile(
      name: 'Secure CI profile',
      insuranceNumber: 'TEST-123',
    );
    await ProfileService.saveProfile(profile);
    final restored = await ProfileService.getProfile();
    expect(restored.name, profile.name);
    expect(restored.insuranceNumber, profile.insuranceNumber);

    final legacyPrefs = await SharedPreferences.getInstance();
    expect(legacyPrefs.getString('user_name'), isNull);

    await DatabaseService.instance.close();
    final reopened = await DatabaseService.instance.getMedPlan();
    expect(reopened.single.drugName, 'CI Test');
    await DatabaseService.instance.close();
  });
}
