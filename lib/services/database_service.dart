import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/drug.dart';
import '../models/med_plan_entry.dart';
import '../models/doctor.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medication_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabelle für den Katalog (Arzneimittel-Datenbank)
    await db.execute('''
      CREATE TABLE drugs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        activeIngredient TEXT NOT NULL,
        dosageForm TEXT NOT NULL
      )
    ''');

    // Tabelle für den persönlichen Medikationsplan (inkl. Vorrat & Status)
    await db.execute('''
      CREATE TABLE med_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drugName TEXT NOT NULL,
        dosage TEXT NOT NULL,
        time TEXT NOT NULL,
        instructions TEXT,
        isActive INTEGER NOT NULL,
        isReminderActive INTEGER NOT NULL,
        selectedDays TEXT NOT NULL,
        stockCount INTEGER NOT NULL DEFAULT 0,
        takenToday INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabelle für die Kontaktliste der Ärzte
    await db.execute('''
      CREATE TABLE doctors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialty TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        openingHours TEXT,
        appointmentUrl TEXT,
        placeId TEXT,
        lastUpdated TEXT
      )
    ''');

    // Beispiel-Medikamente für den Katalog vorbefüllen
    await db.insert('drugs', {'name': 'Ibuprofen 400mg', 'activeIngredient': 'Ibuprofen', 'dosageForm': 'Filmtablette'});
    await db.insert('drugs', {'name': 'Pantoprazol 20mg', 'activeIngredient': 'Pantoprazol', 'dosageForm': 'Magensaftresistente Tablette'});
    await db.insert('drugs', {'name': 'L-Thyroxin 50µg', 'activeIngredient': 'Levothyroxin-Natrium', 'dosageForm': 'Tablette'});
  }

  /// Datenbank-Migration von Version 1 auf 2
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE med_plan ADD COLUMN stockCount INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE med_plan ADD COLUMN takenToday INTEGER NOT NULL DEFAULT 0');
    }
  }

  // Medikationsplan Methoden
  Future<int> insertMedPlanEntry(MedPlanEntry entry) async {
    final db = await instance.database;
    return await db.insert('med_plan', entry.toMap());
  }

  Future<List<MedPlanEntry>> getMedPlan() async {
    final db = await instance.database;
    final result = await db.query('med_plan', orderBy: 'time ASC');
    return result.map((json) => MedPlanEntry.fromMap(json)).toList();
  }

  Future<int> updateMedPlanEntry(MedPlanEntry entry) async {
    final db = await instance.database;
    return await db.update('med_plan', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteMedPlanEntry(int id) async {
    final db = await instance.database;
    return await db.delete('med_plan', where: 'id = ?', whereArgs: [id]);
  }

  /// Aktualisiert den Einnahmestatus und verrechnet den Vorrat automatisch
  Future<void> markAsTaken(MedPlanEntry item, bool taken) async {
    final db = await instance.database;
    int newStock = item.stockCount;

    if (taken && newStock > 0) {
      newStock -= 1;
    } else if (!taken) {
      newStock += 1;
    }

    await db.update(
      'med_plan',
      {
        'takenToday': taken ? 1 : 0,
        'stockCount': newStock,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // Katalog-Suche
  Future<List<Drug>> searchDrugsCatalog(String query) async {
    if (query.isEmpty) return [];
    final db = await instance.database;
    final result = await db.query(
      'drugs',
      where: 'name LIKE ? OR activeIngredient LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return result.map((json) => Drug.fromMap(json)).toList();
  }

  // Ärzte Methoden
  Future<int> insertDoctor(Doctor doctor) async {
    final db = await instance.database;
    return await db.insert('doctors', doctor.toMap());
  }

  Future<List<Doctor>> getDoctors() async {
    final db = await instance.database;
    final result = await db.query('doctors', orderBy: 'name ASC');
    return result.map((json) => Doctor.fromMap(json)).toList();
  }

  Future<int> updateDoctor(Doctor doctor) async {
    final db = await instance.database;
    return await db.update('doctors', doctor.toMap(), where: 'id = ?', whereArgs: [doctor.id]);
  }

  Future<int> deleteDoctor(int id) async {
    final db = await instance.database;
    return await db.delete('doctors', where: 'id = ?', whereArgs: [id]);
  }
}