import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/drug.dart';
import '../models/med_plan_entry.dart';
import '../models/doctor.dart';
import '../models/medical_document.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();

  static Database? _database;

  DatabaseService._init();

  // ============================================================
  // Datenbank
  // ============================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('medication_app.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Aktiviert Foreign Keys.
  ///
  /// Dadurch kann SQLite die Beziehung zwischen Arzt und Dokument
  /// korrekt verwalten.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ============================================================
  // Datenbank neu erstellen
  // ============================================================

  Future<void> _createDB(
    Database db,
    int version,
  ) async {
    // ----------------------------------------------------------
    // Arzneimittel-Katalog
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE drugs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        activeIngredient TEXT NOT NULL,
        dosageForm TEXT NOT NULL
      )
    ''');

    // ----------------------------------------------------------
    // Persönlicher Medikationsplan
    // ----------------------------------------------------------

    await db.execute('''
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

    // ----------------------------------------------------------
    // Ärzte
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE doctors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialty TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        openingHours TEXT NOT NULL DEFAULT '',
        appointmentUrl TEXT,
        placeId TEXT,
        lastUpdated TEXT
      )
    ''');

    // ----------------------------------------------------------
    // Medizinische Dokumente
    //
    // WICHTIG:
    //
    // originalFilePath = tatsächliches Originaldokument
    // ocrText          = separat erkannter OCR-Text
    //
    // OCR verändert niemals das Original.
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE medical_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        title TEXT NOT NULL,

        category TEXT NOT NULL,

        doctorId INTEGER,

        issueDate TEXT NOT NULL,

        originalFilePath TEXT,

        ocrText TEXT NOT NULL DEFAULT '',

        createdAt TEXT NOT NULL,

        updatedAt TEXT NOT NULL,

        FOREIGN KEY (doctorId)
          REFERENCES doctors(id)
          ON DELETE SET NULL
          ON UPDATE CASCADE
      )
    ''');

    // ----------------------------------------------------------
    // Indizes
    //
    // Diese machen spätere Abfragen schneller.
    // ----------------------------------------------------------

    await db.execute('''
      CREATE INDEX idx_medical_documents_doctor
      ON medical_documents(doctorId)
    ''');

    await db.execute('''
      CREATE INDEX idx_medical_documents_issue_date
      ON medical_documents(issueDate)
    ''');

    // ----------------------------------------------------------
    // Grundbestand Arzneimittel
    // ----------------------------------------------------------

    await db.insert(
      'drugs',
      {
        'name': 'Ibuprofen 400mg',
        'activeIngredient': 'Ibuprofen',
        'dosageForm': 'Filmtablette',
      },
    );

    await db.insert(
      'drugs',
      {
        'name': 'Pantoprazol 20mg',
        'activeIngredient': 'Pantoprazol',
        'dosageForm': 'Magensaftresistente Tablette',
      },
    );

    await db.insert(
      'drugs',
      {
        'name': 'L-Thyroxin 50µg',
        'activeIngredient': 'Levothyroxin-Natrium',
        'dosageForm': 'Tablette',
      },
    );
  }

  // ============================================================
  // Datenbank-Migrationen
  // ============================================================

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // ----------------------------------------------------------
    // Version 1 -> Version 2
    // ----------------------------------------------------------

    if (oldVersion < 2) {
      await db.execute(
        '''
        ALTER TABLE med_plan
        ADD COLUMN stockCount INTEGER NOT NULL DEFAULT 0
        ''',
      );

      await db.execute(
        '''
        ALTER TABLE med_plan
        ADD COLUMN takenToday INTEGER NOT NULL DEFAULT 0
        ''',
      );
    }

    // ----------------------------------------------------------
    // Version 2 -> Version 3
    // ----------------------------------------------------------

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE medical_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,

          title TEXT NOT NULL,

          category TEXT NOT NULL,

          doctorId INTEGER,

          issueDate TEXT NOT NULL,

          originalFilePath TEXT,

          ocrText TEXT NOT NULL DEFAULT '',

          createdAt TEXT NOT NULL,

          updatedAt TEXT NOT NULL,

          FOREIGN KEY (doctorId)
            REFERENCES doctors(id)
            ON DELETE SET NULL
            ON UPDATE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_medical_documents_doctor
        ON medical_documents(doctorId)
      ''');

      await db.execute('''
        CREATE INDEX idx_medical_documents_issue_date
        ON medical_documents(issueDate)
      ''');
    }
  }

  // ============================================================
  // Medikationsplan
  // ============================================================

  Future<int> insertMedPlanEntry(
    MedPlanEntry entry,
  ) async {
    final db = await instance.database;

    return await db.insert(
      'med_plan',
      entry.toMap(),
    );
  }

  Future<List<MedPlanEntry>> getMedPlan() async {
    final db = await instance.database;

    final result = await db.query(
      'med_plan',
      orderBy: 'time ASC',
    );

    return result
        .map(
          (json) => MedPlanEntry.fromMap(json),
        )
        .toList();
  }

  Future<int> updateMedPlanEntry(
    MedPlanEntry entry,
  ) async {
    final db = await instance.database;

    return await db.update(
      'med_plan',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteMedPlanEntry(
    int id,
  ) async {
    final db = await instance.database;

    return await db.delete(
      'med_plan',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Aktualisiert den Einnahmestatus und den Vorrat.
  Future<void> markAsTaken(
    MedPlanEntry item,
    bool taken,
  ) async {
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

  // ============================================================
  // Arzneimittel-Katalog
  // ============================================================

  Future<List<Drug>> searchDrugsCatalog(
    String query,
  ) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    final db = await instance.database;

    final result = await db.query(
      'drugs',
      where: '''
        name LIKE ?
        OR activeIngredient LIKE ?
      ''',
      whereArgs: [
        '%$trimmedQuery%',
        '%$trimmedQuery%',
      ],
      orderBy: 'name ASC',
    );

    return result
        .map(
          (json) => Drug.fromMap(json),
        )
        .toList();
  }

  // ============================================================
  // Ärzte
  // ============================================================

  /// Fügt einen neuen Arzt hinzu.
  Future<int> insertDoctor(
    Doctor doctor,
  ) async {
    final db = await instance.database;

    final data = Map<String, dynamic>.from(
      doctor.toMap(),
    );

    // SQLite soll die ID selbst vergeben.
    data.remove('id');

    return await db.insert(
      'doctors',
      data,
    );
  }

  /// Lädt alle gespeicherten Ärzte.
  Future<List<Doctor>> getDoctors() async {
    final db = await instance.database;

    final result = await db.query(
      'doctors',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result
        .map(
          (json) => Doctor.fromMap(json),
        )
        .toList();
  }

  /// Lädt einen einzelnen Arzt.
  Future<Doctor?> getDoctor(
    int id,
  ) async {
    final db = await instance.database;

    final result = await db.query(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Doctor.fromMap(
      result.first,
    );
  }

  /// Sucht lokal nach bereits gespeicherten Ärzten.
  Future<List<Doctor>> searchStoredDoctors(
    String query,
  ) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    final db = await instance.database;

    final result = await db.query(
      'doctors',
      where: '''
        name LIKE ?
        OR specialty LIKE ?
        OR address LIKE ?
      ''',
      whereArgs: [
        '%$trimmedQuery%',
        '%$trimmedQuery%',
        '%$trimmedQuery%',
      ],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result
        .map(
          (json) => Doctor.fromMap(json),
        )
        .toList();
  }

  /// Aktualisiert einen vorhandenen Arzt.
  Future<int> updateDoctor(
    Doctor doctor,
  ) async {
    if (doctor.id == null) {
      throw ArgumentError(
        'Ein Arzt benötigt eine ID zum Aktualisieren.',
      );
    }

    final db = await instance.database;

    final data = Map<String, dynamic>.from(
      doctor.toMap(),
    );

    // ID darf nicht selbst geändert werden.
    data.remove('id');

    return await db.update(
      'doctors',
      data,
      where: 'id = ?',
      whereArgs: [doctor.id],
    );
  }

  /// Löscht einen Arzt.
  ///
  /// Zugehörige Dokumente bleiben erhalten.
  /// Ihre doctorId wird durch ON DELETE SET NULL automatisch
  /// auf null gesetzt.
  Future<int> deleteDoctor(
    int id,
  ) async {
    final db = await instance.database;

    return await db.delete(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // Medizinische Dokumente
  // ============================================================

  /// Speichert ein neues Dokument.
  Future<int> insertMedicalDocument(
    MedicalDocument document,
  ) async {
    final db = await instance.database;

    final data = Map<String, dynamic>.from(
      document.toMap(),
    );

    // SQLite vergibt die ID.
    data.remove('id');

    return await db.insert(
      'medical_documents',
      data,
    );
  }

  /// Lädt alle Dokumente.
  Future<List<MedicalDocument>> getMedicalDocuments() async {
    final db = await instance.database;

    final result = await db.query(
      'medical_documents',
      orderBy: 'issueDate DESC, id DESC',
    );

    return result
        .map(
          (json) => MedicalDocument.fromMap(json),
        )
        .toList();
  }

  /// Lädt nur Arztbriefe.
  Future<List<MedicalDocument>> getDoctorLetters() async {
    final db = await instance.database;

    final result = await db.query(
      'medical_documents',
      where: 'category = ?',
      whereArgs: ['Arztbrief'],
      orderBy: 'issueDate DESC, id DESC',
    );

    return result
        .map(
          (json) => MedicalDocument.fromMap(json),
        )
        .toList();
  }

  /// Lädt ein einzelnes Dokument.
  Future<MedicalDocument?> getMedicalDocument(
    int id,
  ) async {
    final db = await instance.database;

    final result = await db.query(
      'medical_documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MedicalDocument.fromMap(
      result.first,
    );
  }

  /// Lädt alle Dokumente eines bestimmten Arztes.
  Future<List<MedicalDocument>> getDocumentsForDoctor(
    int doctorId,
  ) async {
    final db = await instance.database;

    final result = await db.query(
      'medical_documents',
      where: 'doctorId = ?',
      whereArgs: [doctorId],
      orderBy: 'issueDate DESC, id DESC',
    );

    return result
        .map(
          (json) => MedicalDocument.fromMap(json),
        )
        .toList();
  }

  /// Aktualisiert ein Dokument.
  Future<int> updateMedicalDocument(
    MedicalDocument document,
  ) async {
    if (document.id == null) {
      throw ArgumentError(
        'Ein Dokument benötigt eine ID zum Aktualisieren.',
      );
    }

    final db = await instance.database;

    final data = Map<String, dynamic>.from(
      document
          .copyWith(
            updatedAt: DateTime.now(),
          )
          .toMap(),
    );

    data.remove('id');

    return await db.update(
      'medical_documents',
      data,
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  /// Löscht ein Dokument aus der Datenbank.
  ///
  /// Die Originaldatei wird hier bewusst NICHT gelöscht.
  /// Das übernehmen wir später zentral über den Dokument-Service.
  Future<int> deleteMedicalDocument(
    int id,
  ) async {
    final db = await instance.database;

    return await db.delete(
      'medical_documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // Datenbank schließen
  // ============================================================

  Future<void> close() async {
    final db = await instance.database;

    await db.close();

    _database = null;
  }
}