class MedicalDocument {
  final int? id;

  /// Anzeigename des Dokuments.
  ///
  /// Beispiel:
  /// "Arztbrief vom 15.08.2026"
  final String title;

  /// Dokumenttyp.
  ///
  /// Beispiele:
  /// "Arztbrief", "Diagnose", "Befund", "Entlassbrief"
  final String category;

  /// ID des zugehörigen Arztes aus der doctors-Tabelle.
  ///
  /// Kann null sein, wenn beim Scannen noch kein Arzt
  /// eindeutig zugeordnet werden konnte.
  final int? doctorId;

  /// Ausstelldatum des Dokuments.
  final DateTime issueDate;

  /// Pfad zur ORIGINALDATEI.
  ///
  /// Das ist das tatsächlich fotografierte bzw. gescannte
  /// Dokument. Dieser Inhalt darf niemals durch OCR ersetzt
  /// oder überschrieben werden.
  final String? originalFilePath;

  /// Von OCR erkannter Text.
  ///
  /// OCR ist lediglich eine Zusatzinformation.
  /// Auch bei fehlerhafter OCR bleibt das Originaldokument
  /// vollständig erhalten.
  final String ocrText;

  /// Zeitpunkt, zu dem das Dokument in der App angelegt wurde.
  final DateTime createdAt;

  /// Zeitpunkt der letzten Änderung.
  final DateTime updatedAt;
  
  static const Object _keepDoctorId =
      Object();

  MedicalDocument({
    this.id,
    required this.title,
    required this.category,
    this.doctorId,
    required this.issueDate,
    this.originalFilePath,
    this.ocrText = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Erstellt ein Dokument aus einem SQLite-Datensatz.
  factory MedicalDocument.fromMap(Map<String, dynamic> map) {
    return MedicalDocument(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Dokument',
      category: map['category'] as String? ?? 'Dokument',
      doctorId: map['doctorId'] as int?,
      issueDate: DateTime.tryParse(
            map['issueDate'] as String? ?? '',
          ) ??
          DateTime.now(),
      originalFilePath: map['originalFilePath'] as String?,
      ocrText: map['ocrText'] as String? ?? '',
      createdAt: DateTime.tryParse(
            map['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            map['updatedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  /// Wandelt das Dokument in einen SQLite-kompatiblen Datensatz um.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'category': category,
      'doctorId': doctorId,
      'issueDate': issueDate.toIso8601String(),
      'originalFilePath': originalFilePath,
      'ocrText': ocrText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Erstellt eine Kopie des Dokuments mit geänderten Werten.
  ///
  /// Das brauchen wir später für:
  /// - Dokument bearbeiten
  /// - Arzt zuordnen
  /// - Titel ändern
  /// - Dokumenttyp ändern
  /// - Datum korrigieren
    /// Erstellt eine Kopie des Dokuments mit geänderten Werten.
  ///
  /// Für doctorId wird bewusst zwischen
  /// "nicht ändern" und "auf null setzen" unterschieden.
  ///
  /// Dadurch kann eine bestehende Arztzuordnung
  /// im Bearbeitungsdialog auch wieder entfernt werden.
  MedicalDocument copyWith({
    int? id,
    String? title,
    String? category,
    Object? doctorId = _keepDoctorId,
    DateTime? issueDate,
    String? originalFilePath,
    String? ocrText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      doctorId: identical(doctorId, _keepDoctorId)
          ? this.doctorId
          : doctorId as int?,
      issueDate: issueDate ?? this.issueDate,
      originalFilePath:
          originalFilePath ?? this.originalFilePath,
      ocrText: ocrText ?? this.ocrText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Dateiname für die gespeicherte Originaldatei.
  ///
  /// Der Dateiname dient nur zur Orientierung.
  /// Der tatsächliche Pfad wird in originalFilePath gespeichert.
  String get fileName {
    final formattedDate =
        '${issueDate.year}-'
        '${issueDate.month.toString().padLeft(2, '0')}-'
        '${issueDate.day.toString().padLeft(2, '0')}';

    final sanitizedTitle = title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    final safeTitle =
        sanitizedTitle.isEmpty ? 'Dokument' : sanitizedTitle;

    return '${safeTitle}_$formattedDate';
  }

  /// Formatiertes Ausstelldatum für die Anzeige.
  ///
  /// Beispiel:
  /// 15.08.2026
  String get formattedIssueDate {
    return '${issueDate.day.toString().padLeft(2, '0')}.'
        '${issueDate.month.toString().padLeft(2, '0')}.'
        '${issueDate.year}';
  }

  /// Gibt an, ob tatsächlich eine Originaldatei vorhanden ist.
  bool get hasOriginalFile {
    return originalFilePath != null &&
        originalFilePath!.trim().isNotEmpty;
  }

  /// Gibt an, ob OCR-Text vorhanden ist.
  bool get hasOcrText {
    return ocrText.trim().isNotEmpty;
  }
}