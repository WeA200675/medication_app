import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/med_plan_entry.dart';

class PdfService {
  static Future<void> generateAndSharePdf(
    List<MedPlanEntry> medPlan, {
    String patientName = 'Patient',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Persönlicher Medikationsplan',
                        style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(DateTime.now().toString().split(' ')[0]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text('Patient: $patientName', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Uhrzeit', 'Medikament', 'Dosierung', 'Hinweis'],
                  data: medPlan
                      .map((entry) => [
                            entry.time,
                            entry.drugName,
                            entry.dosage,
                            entry.instructions,
                          ])
                      .toList(),
                  headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  cellHeight: 30,
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.Text(
                  'Erstellt mit der Medikamenten-App',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Medikationsplan_$patientName.pdf',
    );
  }
}