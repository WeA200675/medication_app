import '../models/medical_document.dart';

class MedicalDocParser {
  /// Wandelt den von OCR erkannten Text in ein MedicalDocument um.
  ///
  /// Wichtig:
  /// Der Parser verändert niemals das Originaldokument.
  /// Er erzeugt ausschließlich Metadaten aus dem OCR-Text.
  static MedicalDocument parseOcrResult(
    String rawText, {
    String? originalFilePath,
    int? doctorId,
  }) {
    final text = rawText.trim();

    final issueDate = _extractDate(text);

    final category = _detectCategory(text);

    final title = _createTitle(
      category: category,
      issueDate: issueDate,
    );

    return MedicalDocument(
      title: title,
      category: category,
      doctorId: doctorId,
      issueDate: issueDate,
      originalFilePath: originalFilePath,
      ocrText: text,
    );
  }

  // ============================================================
  // Kategorie erkennen
  // ============================================================

  static String _detectCategory(String text) {
    final normalized = text.toLowerCase();

    if (_containsAny(
      normalized,
      [
        'arztbrief',
        'arztbericht',
        'ärztlicher bericht',
      ],
    )) {
      return 'Arztbrief';
    }

    if (_containsAny(
      normalized,
      [
        'entlassbrief',
        'entlassungsbericht',
        'entlassung',
      ],
    )) {
      return 'Entlassbrief';
    }

    if (_containsAny(
      normalized,
      [
        'befund',
        'befundbericht',
        'laborbefund',
      ],
    )) {
      return 'Befund';
    }

    if (_containsAny(
      normalized,
      [
        'diagnose',
        'diagnosen',
      ],
    )) {
      return 'Diagnose';
    }

    if (_containsAny(
      normalized,
      [
        'rezept',
        'verordnung',
      ],
    )) {
      return 'Rezept';
    }

    return 'Dokument';
  }

  // ============================================================
  // Datum erkennen
  // ============================================================

  static DateTime _extractDate(String text) {
    // Unterstützt beispielsweise:
    //
    // 15.08.2026
    // 15-08-2026
    // 15/08/2026
    //
    // sowie ISO:
    //
    // 2026-08-15

    final germanDateRegex = RegExp(
      r'\b(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{4})\b',
    );

    final germanMatch = germanDateRegex.firstMatch(text);

    if (germanMatch != null) {
      final day = int.tryParse(germanMatch.group(1)!);
      final month = int.tryParse(germanMatch.group(2)!);
      final year = int.tryParse(germanMatch.group(3)!);

      if (day != null &&
          month != null &&
          year != null &&
          _isValidDate(year, month, day)) {
        return DateTime(
          year,
          month,
          day,
        );
      }
    }

    final isoDateRegex = RegExp(
      r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
    );

    final isoMatch = isoDateRegex.firstMatch(text);

    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);

      if (year != null &&
          month != null &&
          day != null &&
          _isValidDate(year, month, day)) {
        return DateTime(
          year,
          month,
          day,
        );
      }
    }

    // Wenn kein Datum erkannt wurde, verwenden wir das aktuelle Datum.
    //
    // Das Originaldokument bleibt davon selbstverständlich
    // unberührt. Der Benutzer kann das Datum später bearbeiten.
    return DateTime.now();
  }

  static bool _isValidDate(
    int year,
    int month,
    int day,
  ) {
    if (month < 1 || month > 12) {
      return false;
    }

    if (day < 1 || day > 31) {
      return false;
    }

    final date = DateTime(
      year,
      month,
      day,
    );

    return date.year == year &&
        date.month == month &&
        date.day == day;
  }

  // ============================================================
  // Titel
  // ============================================================

  static String _createTitle({
    required String category,
    required DateTime issueDate,
  }) {
    final date =
        '${issueDate.day.toString().padLeft(2, '0')}.'
        '${issueDate.month.toString().padLeft(2, '0')}.'
        '${issueDate.year}';

    return '$category vom $date';
  }

  // ============================================================
  // Hilfsfunktion
  // ============================================================

  static bool _containsAny(
    String text,
    List<String> values,
  ) {
    for (final value in values) {
      if (text.contains(value)) {
        return true;
      }
    }

    return false;
  }
}