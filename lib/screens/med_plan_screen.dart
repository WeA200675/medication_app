import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/med_plan_entry.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/email_service.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import 'doctor_letters_screen.dart';

class MedPlanScreen extends StatefulWidget {
  const MedPlanScreen({super.key});

  @override
  State<MedPlanScreen> createState() => _MedPlanScreenState();
}

class _MedPlanScreenState extends State<MedPlanScreen> {
  List<MedPlanEntry> _medPlan = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedPlan();
  }

  Future<void> _loadMedPlan() async {
    try {
      final plan = await DatabaseService.instance.getMedPlan();
      if (!mounted) return;
      setState(() {
        _medPlan = plan;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    }
  }

  Future<void> _scanPackageAndAdd() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Packung wird analysiert...')),
        );
      }

      final rawText = await OcrService.scanDocument(image.path);
      final parsed = OcrService.parseMedicationInfo(rawText);

      if (!mounted) return;

      final recognizedName = parsed['drugName'] ?? '';
      if (recognizedName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name nicht sicher erkannt. Bitte im Formular ergänzen.'),
          ),
        );
      }

      _showAddOrEditDialog(
        prefilledName: recognizedName,
        prefilledDosage: parsed['dosage'] ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Scannen: $e')),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      await BackupService.exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup erfolgreich exportiert!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Exportieren: $e')),
      );
    }
  }

  Future<void> _importData() async {
    try {
      final count = await BackupService.importBackup();
      if (!mounted) return;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count Medikament(e) erfolgreich importiert!')),
        );
        await _loadMedPlan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Daten zum Importieren gefunden.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Importieren: $e')),
      );
    }
  }

  Future<void> _confirmDelete(MedPlanEntry item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medikament löschen'),
        content: Text('Möchtest du "${item.drugName}" wirklich aus dem Plan entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      await DatabaseService.instance.deleteMedPlanEntry(item.id!);
      await NotificationService.instance.cancelReminder(item.id!);
      await _loadMedPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.drugName} gelöscht.')),
      );
    }
  }

  void _showAddOrEditDialog({
    MedPlanEntry? existingEntry,
    String prefilledName = '',
    String prefilledDosage = '',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEditMedicationDialog(
        existingEntry: existingEntry,
        prefilledName: prefilledName,
        prefilledDosage: prefilledDosage,
        onSaved: _loadMedPlan,
      ),
    );
  }

  Widget _buildTableView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_medPlan.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Medikamente eingetragen.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: DataTable(
            border: TableBorder.all(color: Colors.teal.shade300, width: 1.5),
            headingRowColor: WidgetStateProperty.all(Colors.teal.shade100),
            dataRowMaxHeight: 65,
            columns: const [
              DataColumn(
                label: Text(
                  'Uhrzeit',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ),
              DataColumn(
                label: Text(
                  'Medikament',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ),
              DataColumn(
                label: Text(
                  'Dosierung',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ),
              DataColumn(
                label: Text(
                  'Vorrat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ),
              DataColumn(
                label: Text(
                  'Aktionen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ),
            ],
            rows: _medPlan.map((item) {
              final isTaken = item.takenToday;
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      item.time,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.drugName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.dosage,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item.stockCount} Stk.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: item.stockCount < 5 ? Colors.redAccent : Colors.black87,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isTaken ? Icons.check_circle : Icons.check_circle_outline,
                            color: isTaken ? Colors.green : Colors.grey,
                          ),
                          tooltip: isTaken ? 'Als nicht eingenommen markieren' : 'Als eingenommen markieren',
                          onPressed: () async {
                            await DatabaseService.instance.markAsTaken(item, !isTaken);
                            await _loadMedPlan();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          tooltip: 'Bearbeiten',
                          onPressed: () => _showAddOrEditDialog(existingEntry: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          tooltip: 'Löschen',
                          onPressed: () => _confirmDelete(item),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_medPlan.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Medikamente eingetragen.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _medPlan.length,
      itemBuilder: (ctx, index) {
        final item = _medPlan[index];
        final isTaken = item.takenToday;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isTaken ? Colors.green : Colors.teal, width: 1.5),
          ),
          color: isTaken ? Colors.green.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isTaken ? Colors.green.shade700 : Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              title: Text(
                item.drugName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  decoration: isTaken ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Dosierung: ${item.dosage}\n'
                  'Vorrat: ${item.stockCount} Stk.'
                  '${item.instructions.isNotEmpty ? "\nHinweis: ${item.instructions}" : ""}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      isTaken ? Icons.check_circle : Icons.check_circle_outline,
                      color: isTaken ? Colors.green : Colors.grey,
                    ),
                    tooltip: isTaken ? 'Als nicht eingenommen markieren' : 'Als eingenommen markieren',
                    onPressed: () async {
                      await DatabaseService.instance.markAsTaken(item, !isTaken);
                      await _loadMedPlan();
                    },
                  ),
                  IconButton(
                    iconSize: 24,
                    icon: const Icon(Icons.edit, color: Colors.teal),
                    tooltip: 'Bearbeiten',
                    onPressed: () => _showAddOrEditDialog(existingEntry: item),
                  ),
                  IconButton(
                    iconSize: 24,
                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    tooltip: 'Löschen',
                    onPressed: () => _confirmDelete(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mein Medikationsplan'),
          backgroundColor: Colors.teal.shade100,
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(icon: Icon(Icons.table_chart), text: 'Tabelle'),
              Tab(icon: Icon(Icons.view_agenda), text: 'Karten'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_shared),
              tooltip: 'Arztbriefe & Diagnosen',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DoctorLettersScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF Exportieren',
              onPressed: () async {
                if (_medPlan.isNotEmpty) {
                  await PdfService.generateAndSharePdf(_medPlan);
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Keine Einträge vorhanden.')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.email_outlined),
              tooltip: 'Plan per Mail senden',
              onPressed: () async {
                if (_medPlan.isNotEmpty) {
                  await EmailService.sendPlanViaEmail(_medPlan);
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Keine Einträge zum Versenden vorhanden.')),
                  );
                }
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'Backup / Optionen',
              onSelected: (value) {
                if (value == 'export') {
                  _exportData();
                } else if (value == 'import') {
                  _importData();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Backup exportieren'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.download_for_offline, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Backup importieren'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTableView(),
            _buildCardView(),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'scanBtn',
              tooltip: 'Packung scannen',
              onPressed: _scanPackageAndAdd,
              backgroundColor: Colors.teal.shade300,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'addBtn',
              tooltip: 'Manuell hinzufügen',
              onPressed: () => _showAddOrEditDialog(),
              backgroundColor: Colors.teal,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditMedicationDialog extends StatefulWidget {
  final MedPlanEntry? existingEntry;
  final String prefilledName;
  final String prefilledDosage;
  final VoidCallback onSaved;

  const _AddEditMedicationDialog({
    this.existingEntry,
    this.prefilledName = '',
    this.prefilledDosage = '',
    required this.onSaved,
  });

  @override
  State<_AddEditMedicationDialog> createState() => _AddEditMedicationDialogState();
}

class _AddEditMedicationDialogState extends State<_AddEditMedicationDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _dosageCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _instructionsCtrl;
  late TextEditingController _stockCtrl;

  bool get isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _nameCtrl = TextEditingController(text: isEditing ? entry!.drugName : widget.prefilledName);
    _dosageCtrl = TextEditingController(text: isEditing ? entry!.dosage : widget.prefilledDosage);
    _timeCtrl = TextEditingController(text: isEditing ? entry!.time : '08:00');
    _instructionsCtrl = TextEditingController(text: isEditing ? entry!.instructions : '');
    _stockCtrl = TextEditingController(text: isEditing ? entry!.stockCount.toString() : '0');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _timeCtrl.dispose();
    _instructionsCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final drugName = _nameCtrl.text.trim();

    if (drugName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib einen Medikamentennamen ein.'),
        ),
      );
      return;
    }

    try {
      final existing = widget.existingEntry;
      final entryToSave = MedPlanEntry(
        id: isEditing ? existing!.id : null,
        drugName: drugName,
        dosage: _dosageCtrl.text.trim(),
        time: _timeCtrl.text.trim().isEmpty ? '08:00' : _timeCtrl.text.trim(),
        instructions: _instructionsCtrl.text.trim(),
        isActive: isEditing ? existing!.isActive : true,
        isReminderActive: isEditing ? existing!.isReminderActive : true,
        selectedDays: isEditing
            ? existing!.selectedDays
            : const [1, 2, 3, 4, 5, 6, 7],
        stockCount: int.tryParse(_stockCtrl.text.trim()) ?? 0,
        takenToday: isEditing ? existing!.takenToday : false,
      );

      if (isEditing) {
        await DatabaseService.instance.updateMedPlanEntry(entryToSave);
        await NotificationService.instance.scheduleMedicationReminder(entryToSave);
      } else {
        final id = await DatabaseService.instance.insertMedPlanEntry(entryToSave);
        final savedEntry = MedPlanEntry(
          id: id,
          drugName: entryToSave.drugName,
          dosage: entryToSave.dosage,
          time: entryToSave.time,
          instructions: entryToSave.instructions,
          isActive: entryToSave.isActive,
          isReminderActive: entryToSave.isReminderActive,
          selectedDays: entryToSave.selectedDays,
          stockCount: entryToSave.stockCount,
          takenToday: entryToSave.takenToday,
        );
        await NotificationService.instance.scheduleMedicationReminder(savedEntry);
      }

      if (!mounted) return;

      // Dialog schließen und Medikationsliste aktualisieren
      Navigator.of(context).pop();
      widget.onSaved();

      // SnackBar auf dem Hauptbildschirm anzeigen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? '$drugName aktualisiert!' : '$drugName gespeichert!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Medikament bearbeiten' : 'Medikament hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name des Medikaments'),
            ),
            TextField(
              controller: _dosageCtrl,
              decoration: const InputDecoration(labelText: 'Dosierung (z. B. 400 mg)'),
            ),
            TextField(
              controller: _timeCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Uhrzeit',
                suffixIcon: Icon(Icons.access_time),
              ),
              onTap: () async {
                final currentParts = _timeCtrl.text.split(':');
                int hour = 8;
                int minute = 0;
                if (currentParts.length == 2) {
                  hour = int.tryParse(currentParts[0]) ?? 8;
                  minute = int.tryParse(currentParts[1]) ?? 0;
                }
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                );
                if (pickedTime != null && mounted) {
                  final formattedHour = pickedTime.hour.toString().padLeft(2, '0');
                  final formattedMinute = pickedTime.minute.toString().padLeft(2, '0');
                  setState(() {
                    _timeCtrl.text = '$formattedHour:$formattedMinute';
                  });
                }
              },
            ),
            TextField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Hinweise (z. B. vor dem Essen)',
              ),
            ),
            TextField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Vorrat (Anzahl)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}