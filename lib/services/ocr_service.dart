import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  /// Liest den gesamten Text aus einem Bild
  static Future<String> scanDocument(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await textRecognizer.close();
    }
  }

  /// Extrahiert gezielt Medikamentenname und Dosierung aus dem gescannten Text
  static Map<String, String> parseMedicationInfo(String rawText) {
    if (rawText.trim().isEmpty) {
      return {'drugName': '', 'dosage': '', 'rawText': ''};
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Der Medikamentenname steht meistens in der ersten prägnanten Zeile
    String drugName = lines.isNotEmpty ? lines.first : '';

    // Regulärer Ausdruck für typische Dosierungen (z. B. 400mg, 500 mg, 20 ml, 100 µg)
    final RegExp dosageRegExp = RegExp(
      r'\d+\s*(mg|g|ml|µg|Stück|IE)',
      caseSensitive: false,
    );

    String dosage = '';
    final match = dosageRegExp.firstMatch(rawText);
    if (match != null) {
      dosage = match.group(0) ?? '';
    }

    return {
      'drugName': drugName,
      'dosage': dosage,
      'rawText': rawText,
    };
  }
}