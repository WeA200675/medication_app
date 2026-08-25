import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/medical_document.dart';
import '../services/medical_doc_parser.dart';
import '../services/ocr_service.dart';

class DoctorLettersScreen extends StatefulWidget {
  const DoctorLettersScreen({super.key});

  @override
  State<DoctorLettersScreen> createState() => _DoctorLettersScreenState();
}

class _DoctorLettersScreenState extends State<DoctorLettersScreen> {
  // Ansichtsmodus: true = Kacheln (Grid), false = Liste
  bool _isGridView = true;

  // Beispieldaten (werden chronologisch sortiert)
  final List<MedicalDocument> _documents = [
    MedicalDocument(
      id: 1,
      doctorOrPractice: 'Dr. med. Weber - Kardiologie',
      issueDate: DateTime(2026, 8, 12),
      category: 'Arztbrief',
      previewText:
          'Patient zeigt unauffälliges Belastungs-EKG. Blutfettwerte stabil. Nächste Kontrolle in 6 Monaten empfohlen.',
    ),
    MedicalDocument(
      id: 2,
      doctorOrPractice: 'Radiologisches Zentrum Landshut',
      issueDate: DateTime(2026, 6, 20),
      category: 'Diagnose',
      previewText:
          'MRT der Lendenwirbelsäule: Keine gravierenden Bandscheibenvorfälle erkennbar. Leichte Verschleißerscheinungen L4/L5.',
    ),
    MedicalDocument(
      id: 3,
      doctorOrPractice: 'Praxis Dr. Hausarzt',
      issueDate: DateTime(2026, 1, 10),
      category: 'Arztbrief',
      previewText:
          'Jahres-Check-up ohne Befund. Blutdruck im Normbereich. Impfschutz aufgefrischt.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sortDocumentsDescending();
  }

  /// Sortiert die Dokumente chronologisch absteigend (neueste zuerst)
  void _sortDocumentsDescending() {
    _documents.sort((a, b) => b.issueDate.compareTo(a.issueDate));
  }

  /// Dokument per Kamera scannen und automatisch benennen
  Future<void> _scanAndAddDocument() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokument wird analysiert...')),
        );
      }

      final rawText = await OcrService.scanDocument(image.path);
      final newDoc = MedicalDocParser.parseOcrResult(rawText, category: 'Arztbrief');

      if (!mounted) return;

      setState(() {
        _documents.add(newDoc);
        _sortDocumentsDescending();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gespeichert als: ${newDoc.fileName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Scannen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arztbriefe & Diagnosen'),
        backgroundColor: Colors.teal.shade100,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'Zur Listenansicht' : 'Zur Kachelansicht',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: _documents.isEmpty
          ? const Center(
              child: Text(
                'Keine Dokumente vorhanden.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : _isGridView
              ? _buildGridView()
              : _buildListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanAndAddDocument,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.document_scanner, color: Colors.white),
        label: const Text('Dokument scannen', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Kachel-Ansicht (Grid)
  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _documents.length,
      itemBuilder: (ctx, index) {
        final doc = _documents[index];
        final isArztbrief = doc.category.toLowerCase() == 'arztbrief';

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isArztbrief ? Colors.teal.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isArztbrief ? Colors.teal.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                    Text(
                      doc.formattedIssueDate,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  doc.doctorOrPractice,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const Divider(height: 10),
                Expanded(
                  child: Text(
                    doc.previewText,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.2),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 12, color: Colors.teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doc.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: Colors.teal, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Listen-Ansicht
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _documents.length,
      itemBuilder: (ctx, index) {
        final doc = _documents[index];
        final isArztbrief = doc.category.toLowerCase() == 'arztbrief';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isArztbrief ? Colors.teal.shade100 : Colors.orange.shade100,
              child: Icon(
                isArztbrief ? Icons.description : Icons.health_and_safety,
                color: isArztbrief ? Colors.teal : Colors.orange,
              ),
            ),
            title: Text(
              doc.doctorOrPractice,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Datum: ${doc.formattedIssueDate} | Datei: ${doc.fileName}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  doc.previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              // Option zum Öffnen des Dokuments
            },
          ),
        );
      },
    );
  }
}