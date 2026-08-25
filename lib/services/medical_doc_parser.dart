import '../models/medical_document.dart';

class MedicalDocParser {
  /// Liest gescannten Text aus und ermittelt Arzt/Praxis und Ausstelldatum
  static MedicalDocument parseOcrResult(String rawText, {String category = 'Arztbrief'}) {
    // 1. Ausstelldatum per Regular Expression suchen (Format: DD.MM.YYYY)
    DateTime extractedDate = DateTime.now();
    final dateRegExp = RegExp(r'\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b');
    final dateMatch = dateRegExp.firstMatch(rawText);
    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final year = int.parse(dateMatch.group(3)!);
      extractedDate = DateTime(year, month, day);
    }

    // 2. Ersteller/Praxis aus dem Text extrahieren
    String extractedDoctor = "Unbekannte Praxis";
    final doctorRegExp = RegExp(
      r'(Dr\.\s*med\.\s*[\w\s\-]+|Praxis\s+[\w\s\-]+|Klinikum\s+[\w\s\-]+|Gemeinschaftspraxis\s+[\w\s\-]+)',
      caseSensitive: false,
    );
    final docMatch = doctorRegExp.firstMatch(rawText);
    if (docMatch != null) {
      extractedDoctor = docMatch.group(0)!.trim();
    }

    // 3. Vorschau erstellen (erste 120 Zeichen)
    final cleanedText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = cleanedText.length > 120
        ? '${cleanedText.substring(0, 120)}...'
        : cleanedText;

    return MedicalDocument(
      doctorOrPractice: extractedDoctor,
      issueDate: extractedDate,
      category: category,
      previewText: preview.isEmpty ? 'Keine Textvorschau verfügbar.' : preview,
    );
  }
}