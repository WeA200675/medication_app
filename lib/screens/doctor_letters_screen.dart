import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/doctor.dart';
import '../models/medical_document.dart';
import '../services/database_service.dart';
import '../services/medical_doc_parser.dart';
import '../services/ocr_service.dart';

class DoctorLettersScreen extends StatefulWidget {
  const DoctorLettersScreen({super.key});

  @override
  State<DoctorLettersScreen> createState() => _DoctorLettersScreenState();
}

class _DoctorLettersScreenState extends State<DoctorLettersScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;

  bool _isGridView = true;
  bool _isLoading = true;
  bool _isScanning = false;

  List<MedicalDocument> _documents = [];
  List<Doctor> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // Daten laden
  // ============================================================

  Future<void> _loadData() async {
    try {
      final documents =
          await _databaseService.getMedicalDocuments();

      final doctors =
          await _databaseService.getDoctors();

      if (!mounted) return;

      setState(() {
        _documents = documents;
        _doctors = doctors;
        _sortDocumentsDescending();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Fehler beim Laden der Dokumente: $e',
        isError: true,
      );
    }
  }

  void _sortDocumentsDescending() {
    _documents.sort(
      (a, b) => b.issueDate.compareTo(a.issueDate),
    );
  }

  // ============================================================
  // Arzt ermitteln
  // ============================================================

  String _doctorNameForDocument(
    MedicalDocument document,
  ) {
    if (document.doctorId == null) {
      return 'Kein Arzt zugeordnet';
    }

    for (final doctor in _doctors) {
      if (doctor.id == document.doctorId) {
        return doctor.name;
      }
    }

    return 'Arzt nicht gefunden';
  }

  // ============================================================
  // Dokument scannen
  // ============================================================

  Future<void> _scanAndAddDocument() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      _showMessage(
        'Originaldokument wird gespeichert...',
      );

      // --------------------------------------------------------
      // 1. Originalbild dauerhaft speichern
      // --------------------------------------------------------

      final originalFilePath =
          await _saveOriginalDocument(image);

      if (!mounted) return;

      _showMessage(
        'Dokument wird per OCR analysiert...',
      );

      // --------------------------------------------------------
      // 2. OCR durchführen
      //
      // Wichtig:
      // Das OCR-Ergebnis ersetzt NIEMALS das Originalbild.
      // --------------------------------------------------------

      String rawText = '';

      try {
        rawText = await OcrService.scanDocument(
          image.path,
        );
      } catch (e) {
        // Das Original soll auch dann erhalten bleiben,
        // wenn OCR einmal fehlschlägt.
        rawText = '';

        debugPrint(
          'OCR-Fehler: $e',
        );
      }

      // --------------------------------------------------------
      // 3. MedicalDocument aus OCR erzeugen
      // --------------------------------------------------------

      final newDocument =
          MedicalDocParser.parseOcrResult(
        rawText,
        originalFilePath: originalFilePath,
      );

      // --------------------------------------------------------
      // 4. Dokument dauerhaft in SQLite speichern
      // --------------------------------------------------------

      final insertedId =
          await _databaseService.insertMedicalDocument(
        newDocument,
      );

      final savedDocument =
          newDocument.copyWith(
        id: insertedId,
      );

      if (!mounted) return;

      setState(() {
        _documents.add(savedDocument);
        _sortDocumentsDescending();
      });

      if (rawText.trim().isEmpty) {
        _showMessage(
          'Dokument gespeichert. OCR konnte keinen Text erkennen.',
        );
      } else {
        _showMessage(
          'Dokument erfolgreich gespeichert.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Fehler beim Scannen: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // ============================================================
  // Originaldatei speichern
  // ============================================================

  Future<String> _saveOriginalDocument(
    XFile image,
  ) async {
    final appDirectory =
        await getApplicationDocumentsDirectory();

    final documentsDirectory = Directory(
      p.join(
        appDirectory.path,
        'medical_documents',
      ),
    );

    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(
        recursive: true,
      );
    }

    final extension =
        p.extension(image.path).toLowerCase();

    final safeExtension =
        extension.isEmpty ? '.jpg' : extension;

    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    final targetPath = p.join(
      documentsDirectory.path,
      'medical_document_$timestamp$safeExtension',
    );

    final sourceFile = File(image.path);

    if (!await sourceFile.exists()) {
      throw Exception(
        'Das aufgenommene Originalbild konnte nicht gefunden werden.',
      );
    }

    final savedFile =
        await sourceFile.copy(targetPath);

    return savedFile.path;
  }

  // ============================================================
  // Dokument öffnen
  // ============================================================

  Future<void> _openDocument(
    MedicalDocument document,
  ) async {
    final path = document.originalFilePath;

    if (path == null || path.trim().isEmpty) {
      _showMessage(
        'Für dieses Dokument ist keine Originaldatei gespeichert.',
        isError: true,
      );
      return;
    }

    final file = File(path);

    if (!await file.exists()) {
      _showMessage(
        'Die Originaldatei wurde nicht gefunden.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    final extension =
        p.extension(path).toLowerCase();

    if (extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.png' ||
        extension == '.webp') {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: Text(
                      document.title,
                    ),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      _showMessage(
        'Dieser Dateityp kann momentan noch nicht direkt angezeigt werden.',
      );
    }
  }
  // ============================================================
  // Dokument bearbeiten
  // ============================================================

  Future<void> _editDocument(
    MedicalDocument document,
  ) async {
    if (document.id == null) {
      return;
    }
    String doctorDisplayName(Doctor doctor) {
      final name = doctor.name.trim();
      final specialty = doctor.specialty.trim();

      if (name.isEmpty && specialty.isEmpty) {
        return 'Unbekannter Arzt';
      }

      if (specialty.isEmpty) {
        return name;
      }

      if (name.isEmpty) {
        return specialty;
      }

      return '$name – $specialty';
    }

  final doctors =
      await _databaseService.getDoctors();

    String editedTitle = document.title;
    String editedOcrText = document.ocrText;
    String selectedCategory = document.category;
    DateTime selectedDate = document.issueDate;
    int? selectedDoctorId = document.doctorId;

    final categories = <String>[
      'Arztbrief',
      'Entlassbrief',
      'Befund',
      'Diagnose',
      'Rezept',
      'Dokument',
    ];

    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Dokument bearbeiten',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ------------------------------------------------
                    // Titel
                    // ------------------------------------------------

                    TextFormField(
                      initialValue: document.title,
                      onChanged: (value) {
                        editedTitle = value;
                      },
                      decoration:
                          const InputDecoration(
                        labelText: 'Titel',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ------------------------------------------------
                    // Kategorie
                    // ------------------------------------------------

                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration:
                          const InputDecoration(
                        labelText: 'Kategorie',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map(
                        (category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // ------------------------------------------------
                    // Arzt / Praxis
                    // ------------------------------------------------

                    DropdownButtonFormField<int?>(
                      initialValue: selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: 'Arzt / Praxis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Keine Zuordnung',
                          ),
                        ),

                        ...doctors.map(
                          (doctor) {
                            return DropdownMenuItem<int?>(
                              value: doctor.id,
                              child: Text(
                                doctorDisplayName(doctor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDoctorId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),
                    // ------------------------------------------------
                    // Dokumentdatum
                    // ------------------------------------------------

                    InkWell(
                      onTap: () async {
                        final pickedDate =
                            await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedDate = pickedDate;
                        });
                      },
                      borderRadius:
                          BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Dokumentdatum',
                          border:
                              OutlineInputBorder(),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                          ),
                        ),
                        child: Text(
                          _formatDate(
                            selectedDate,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ------------------------------------------------
                    // OCR-Text
                    // ------------------------------------------------

                    TextFormField(
                      initialValue: document.ocrText,
                      maxLines: 8,
                      onChanged: (value) {
                        editedOcrText = value;
                      },
                      decoration:
                          const InputDecoration(
                        labelText: 'OCR-Text',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ------------------------------------------------
                    // Hinweis
                    // ------------------------------------------------

                    Text(
                      'Das Originalfoto bleibt unverändert.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade600,
                        fontStyle:
                            FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop(false);
                  },
                  child: const Text(
                    'Abbrechen',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final title =
                        editedTitle.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Der Titel darf nicht leer sein.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(true);
                  },
                  icon: const Icon(
                    Icons.save,
                  ),
                  label: const Text(
                    'Speichern',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // --------------------------------------------------------------
    // Dialog wurde geschlossen
    // --------------------------------------------------------------

    if (result != true) {
      return;
    }

    final title = editedTitle.trim();
    final ocrText = editedOcrText.trim();

    if (title.isEmpty) {
      _showMessage(
        'Der Titel darf nicht leer sein.',
        isError: true,
      );
      return;
    }

    try {
      // ------------------------------------------------------------
      // Geändertes Dokument erzeugen
      //
      // Das Originalbild / originalFilePath wird absichtlich
      // NICHT verändert.
      // ------------------------------------------------------------

        final updatedDocument =
            document.copyWith(
          title: title,
          category: selectedCategory,
          issueDate: selectedDate,
          doctorId: selectedDoctorId,
          ocrText: ocrText,
          updatedAt: DateTime.now(),
        );

      // ------------------------------------------------------------
      // Datenbank aktualisieren
      // ------------------------------------------------------------

      await _databaseService
          .updateMedicalDocument(
        updatedDocument,
      );

      if (!mounted) {
        return;
      }

      // ------------------------------------------------------------
      // Lokale Liste aktualisieren
      // ------------------------------------------------------------

      setState(() {
        final index = _documents.indexWhere(
          (item) =>
              item.id == document.id,
        );

        if (index != -1) {
          _documents[index] =
              updatedDocument;
        }

        _sortDocumentsDescending();
      });

      _showMessage(
        'Dokument wurde aktualisiert.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Fehler beim Speichern: $e',
        isError: true,
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
  
  // ============================================================
  // Dokument löschen
  // ============================================================

  Future<void> _deleteDocument(
    MedicalDocument document,
  ) async {
    if (document.id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dokument löschen?'),
          content: Text(
            'Soll "${document.title}" wirklich gelöscht werden?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      // Datenbankeintrag löschen.
      await _databaseService.deleteMedicalDocument(
        document.id!,
      );

      // Originaldatei ebenfalls löschen.
      if (document.originalFilePath != null &&
          document.originalFilePath!.trim().isNotEmpty) {
        final file = File(
          document.originalFilePath!,
        );

        if (await file.exists()) {
          await file.delete();
        }
      }

      if (!mounted) return;

      setState(() {
        _documents.removeWhere(
          (item) => item.id == document.id,
        );
      });

      _showMessage(
        'Dokument gelöscht.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Fehler beim Löschen: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // OCR-Text anzeigen
  // ============================================================

  Future<void> _showOcrText(
    MedicalDocument document,
  ) async {
    if (document.ocrText.trim().isEmpty) {
      _showMessage(
        'Für dieses Dokument wurde kein OCR-Text erkannt.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erkannter OCR-Text'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                document.ocrText,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // Dokument-Menü
  // ============================================================

  Future<void> _showDocumentMenu(
    MedicalDocument document,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                ),
                title: const Text(
                  'Originaldokument öffnen',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _openDocument(document);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.text_snippet_outlined,
                ),
                title: const Text(
                  'OCR-Text anzeigen',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showOcrText(document);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                ),
                title: const Text(
                  'Dokument löschen',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteDocument(document);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // Benutzerfeedback
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : null,
        ),
      );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Arztbriefe & Diagnosen',
        ),
        backgroundColor: Colors.teal.shade100,
        actions: [
          IconButton(
            icon: Icon(
              _isGridView
                  ? Icons.view_list
                  : Icons.grid_view,
            ),
            tooltip: _isGridView
                ? 'Zur Listenansicht'
                : 'Zur Kachelansicht',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),

      body: _buildBody(),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _isScanning ? null : _scanAndAddDocument,
        backgroundColor:
            _isScanning ? Colors.grey : Colors.teal,
        icon: _isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.document_scanner,
                color: Colors.white,
              ),
        label: Text(
          _isScanning
              ? 'Dokument wird verarbeitet...'
              : 'Dokument scannen',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Icon(
                Icons.folder_open_outlined,
                size: 64,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Noch keine Dokumente vorhanden.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Über „Dokument scannen“ kannst du den ersten Arztbrief hinzufügen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: _isGridView
          ? _buildGridView()
          : _buildListView(),
    );
  }

  // ============================================================
  // Grid
  // ============================================================

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        100,
      ),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final document = _documents[index];

        return _buildDocumentCard(
          document,
        );
      },
    );
  }

  Widget _buildDocumentCard(
    MedicalDocument document,
  ) {
    final isArztbrief =
        document.category.toLowerCase() ==
            'arztbrief';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDocument(document),
        onLongPress: () =>
            _showDocumentMenu(document),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isArztbrief
                            ? Colors.teal.shade100
                            : Colors.orange.shade100,
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                      child: Text(
                        document.category,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: isArztbrief
                              ? Colors.teal.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'open') {
                        _openDocument(document);
                      }  else if (value == 'edit') {
                        _editDocument(document);
                      } else if (value == 'ocr') {
                        _showOcrText(document);
                      } else if (value == 'delete') {
                        _deleteDocument(document);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'open',
                        child: Text(
                          'Original öffnen',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Bearbeiten',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'ocr',
                        child: Text(
                          'OCR-Text',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Löschen',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                document.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                _doctorNameForDocument(
                  document,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                document.formattedIssueDate,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Divider(height: 14),

              Expanded(
                child: Text(
                  document.hasOcrText
                      ? document.ocrText
                      : 'Kein OCR-Text erkannt.',
                  maxLines: 5,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    height: 1.25,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Icon(
                    document.hasOriginalFile
                        ? Icons.image_outlined
                        : Icons
                            .image_not_supported_outlined,
                    size: 14,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      document.hasOriginalFile
                          ? 'Original vorhanden'
                          : 'Kein Original',
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.teal,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Liste
  // ============================================================

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        100,
      ),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final document = _documents[index];

        final isArztbrief =
            document.category.toLowerCase() ==
                'arztbrief';

        return Card(
          elevation: 2,
          margin:
              const EdgeInsets.symmetric(
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isArztbrief
                  ? Colors.teal.shade100
                  : Colors.orange.shade100,
              child: Icon(
                isArztbrief
                    ? Icons.description
                    : Icons.health_and_safety,
                color: isArztbrief
                    ? Colors.teal
                    : Colors.orange,
              ),
            ),
            title: Text(
              document.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  _doctorNameForDocument(
                    document,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Datum: ${document.formattedIssueDate}',
                  style: const TextStyle(
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  document.hasOcrText
                      ? document.ocrText
                      : 'Kein OCR-Text erkannt.',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'open') {
                  _openDocument(document);
                } else if (value == 'ocr') {
                  _showOcrText(document);
                } else if (value == 'delete') {
                  _deleteDocument(document);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'open',
                  child: Text(
                    'Original öffnen',
                  ),
                ),
                PopupMenuItem(
                  value: 'ocr',
                  child: Text(
                    'OCR-Text',
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Löschen',
                  ),
                ),
              ],
            ),
            onTap: () => _openDocument(
              document,
            ),
          ),
        );
      },
    );
  }
}