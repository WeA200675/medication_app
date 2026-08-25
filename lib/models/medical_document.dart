class MedicalDocument {
  final int? id;
  final String doctorOrPractice; // Ersteller des Briefes / Praxis
  final DateTime issueDate;       // Ausstelldatum
  final String category;         // z. B. "Arztbrief" oder "Diagnose"
  final String previewText;       // Kurze Vorschau des Inhalts
  final String? filePath;        // Pfad zur abgespeicherten Datei

  MedicalDocument({
    this.id,
    required this.doctorOrPractice,
    required this.issueDate,
    required this.category,
    required this.previewText,
    this.filePath,
  });

  /// Generiert den Dateinamen aus Ersteller + Ausstelldatum
  /// Beispiel: "Arztbrief_Dr_Med_Mueller_2026-08-15.pdf"
  String get fileName {
    final formattedDate =
        "${issueDate.year}-${issueDate.month.toString().padLeft(2, '0')}-${issueDate.day.toString().padLeft(2, '0')}";
    final sanitizedDoctor = doctorOrPractice
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return "${category}_${sanitizedDoctor}_$formattedDate.pdf";
  }

  /// Formatiertes Ausstelldatum für die Anzeige (z. B. 15.08.2026)
  String get formattedIssueDate {
    return "${issueDate.day.toString().padLeft(2, '0')}.${issueDate.month.toString().padLeft(2, '0')}.${issueDate.year}";
  }
}