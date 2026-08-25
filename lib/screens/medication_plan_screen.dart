import 'package:flutter/material.dart';

/// Immutable model representing a single medication entry.
@immutable
class MedicationItem {
  final String id;
  final String ean;
  final String name;
  final String dosage;
  final String morning;
  final String noon;
  final String evening;
  final String night;
  final String unit;
  final String instructions;
  final bool hasChanged;

  const MedicationItem({
    required this.id,
    required this.ean,
    required this.name,
    required this.dosage,
    required this.morning,
    required this.noon,
    required this.evening,
    required this.night,
    required this.unit,
    required this.instructions,
    this.hasChanged = false,
  });

  MedicationItem copyWith({
    String? id,
    String? ean,
    String? name,
    String? dosage,
    String? morning,
    String? noon,
    String? evening,
    String? night,
    String? unit,
    String? instructions,
    bool? hasChanged,
  }) {
    return MedicationItem(
      id: id ?? this.id,
      ean: ean ?? this.ean,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      morning: morning ?? this.morning,
      noon: noon ?? this.noon,
      evening: evening ?? this.evening,
      night: night ?? this.night,
      unit: unit ?? this.unit,
      instructions: instructions ?? this.instructions,
      hasChanged: hasChanged ?? this.hasChanged,
    );
  }
}

class MedicationPlanScreen extends StatefulWidget {
  const MedicationPlanScreen({super.key});

  @override
  State<MedicationPlanScreen> createState() => _MedicationPlanScreenState();
}

enum ViewMode { tabs, table }

class _MedicationPlanScreenState extends State<MedicationPlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ViewMode _currentViewMode = ViewMode.tabs;

  // Mock-Datenbank für EAN-Lookups
  final Map<String, Map<String, String>> _eanDatabase = {
    '4012345678901': {
      'name': 'Pantoprazol 20 mg',
      'dosage': '20 mg',
      'unit': 'Magensaftresistente Tablette',
      'instructions': 'Vor dem Frühstück',
    },
    '4098765432109': {
      'name': 'Ramipril 5 mg',
      'dosage': '5 mg',
      'unit': 'Tablette',
      'instructions': 'Morgens einnehmen',
    },
  };

  final List<MedicationItem> _medications = [
    const MedicationItem(
      id: '1',
      ean: '4012345678901',
      name: 'Pantoprazol',
      dosage: '20 mg',
      morning: '1',
      noon: '0',
      evening: '0',
      night: '0',
      unit: 'Stk',
      instructions: 'Vor dem Essen',
      hasChanged: false,
    ),
    const MedicationItem(
      id: '2',
      ean: '4098765432109',
      name: 'Ramipril',
      dosage: '5 mg',
      morning: '1',
      noon: '0',
      evening: '0',
      night: '0',
      unit: 'Stk',
      instructions: 'Nach dem Aufstehen',
      hasChanged: true, // Warnung/Dosisänderung
    ),
    const MedicationItem(
      id: '3',
      ean: '4022334455667',
      name: 'Metformin',
      dosage: '850 mg',
      morning: '1',
      noon: '0',
      evening: '1',
      night: '0',
      unit: 'Stk',
      instructions: 'Zum Essen',
      hasChanged: false,
    ),
    const MedicationItem(
      id: '4',
      ean: '4055667788990',
      name: 'Simvastatin',
      dosage: '20 mg',
      morning: '0',
      noon: '0',
      evening: '0',
      night: '1',
      unit: 'Stk',
      instructions: 'Vor dem Schlafengehen',
      hasChanged: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openEanScanDialog({MedicationItem? existingMed}) {
    final controller = TextEditingController(text: existingMed?.ean ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingMed != null ? 'EAN scannen / abgleichen' : 'Neues Medikament scannen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Geben Sie die EAN/PZN manuell ein oder simulieren Sie den Barcode-Scan:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'EAN Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              final ean = controller.text.trim();
              controller.dispose();
              Navigator.pop(ctx);
              _processScannedEan(ean, existingMed);
            },
            child: const Text('Prüfen'),
          ),
        ],
      ),
    );
  }

  void _processScannedEan(String ean, MedicationItem? existingMed) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (ean.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Keine EAN eingegeben.')),
      );
      return;
    }

    if (existingMed != null) {
      // Abgleich mit einem bestimmten Eintrag
      if (existingMed.ean == ean) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('Bestätigt: ${existingMed.name} stimmt überein.'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Warnung: Scancode ($ean) weicht von ${existingMed.name} ab!'),
          ),
        );
      }
    } else {
      // Freier Scan: Prüfen, ob bereits im Plan vorhanden oder in Datenbank existent
      final existingIndex = _medications.indexWhere((m) => m.ean == ean);
      final foundInDb = _eanDatabase[ean];

      if (existingIndex != -1) {
        final med = _medications[existingIndex];
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue.shade700,
            content: Text('Im Plan gefunden: ${med.name} (${med.dosage})'),
          ),
        );
      } else if (foundInDb != null) {
        setState(() {
          _medications.add(
            MedicationItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              ean: ean,
              name: foundInDb['name']!,
              dosage: foundInDb['dosage']!,
              morning: '1',
              noon: '0',
              evening: '0',
              night: '0',
              unit: foundInDb['unit']!,
              instructions: foundInDb['instructions']!,
              hasChanged: false,
            ),
          );
        });
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('Hinzugefügt: ${foundInDb['name']}'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            content: Text('EAN $ean nicht in Datenbank gefunden.'),
          ),
        );
      }
    }
  }

  void _openDoctorEmailDialog() {
    final emailController = TextEditingController(text: 'praxis@hausarzt.de');
    final messageController = TextEditingController(
      text: 'Sehr geehrtes Praxisteam,\n\nanbei übersende ich meinen aktuellen Medikationsplan zur Überprüfung.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medikationsplan senden'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Empfänger E-Mail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nachricht',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              emailController.dispose();
              messageController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Senden'),
            onPressed: () {
              final recipient = emailController.text.trim();
              emailController.dispose();
              messageController.dispose();
              Navigator.pop(ctx);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Plan erfolgreich an $recipient gesendet!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = const Color(0xFFD81B60);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Medikationsplan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Barcode scannen',
            onPressed: () => _openEanScanDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            tooltip: 'An Arzt senden',
            onPressed: _openDoctorEmailDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SegmentedButton<ViewMode>(
              segments: const [
                ButtonSegment(
                  value: ViewMode.tabs,
                  label: Text('Tageszeiten'),
                  icon: Icon(Icons.view_day),
                ),
                ButtonSegment(
                  value: ViewMode.table,
                  label: Text('Gesamtplan'),
                  icon: Icon(Icons.table_chart),
                ),
              ],
              selected: {_currentViewMode},
              onSelectionChanged: (Set<ViewMode> newSelection) {
                setState(() {
                  _currentViewMode = newSelection.first;
                });
              },
            ),
          ),
        ),
      ),
      body: _currentViewMode == ViewMode.tabs
          ? _buildTabsView(highlightColor)
          : _buildTableView(highlightColor),
    );
  }

  Widget _buildTabsView(Color highlightColor) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Morgens', icon: Icon(Icons.wb_sunny_outlined)),
            Tab(text: 'Mittags', icon: Icon(Icons.wb_sunny)),
            Tab(text: 'Abends', icon: Icon(Icons.nights_stay_outlined)),
            Tab(text: 'Nachts', icon: Icon(Icons.bedtime)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTimeSlotList((m) => m.morning, highlightColor),
              _buildTimeSlotList((m) => m.noon, highlightColor),
              _buildTimeSlotList((m) => m.evening, highlightColor),
              _buildTimeSlotList((m) => m.night, highlightColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotList(String Function(MedicationItem) getDose, Color highlightColor) {
    final activeMeds = _medications.where((m) => getDose(m) != '0' && getDose(m).isNotEmpty).toList();

    if (activeMeds.isEmpty) {
      return const Center(
        child: Text(
          'Keine Medikamente für diese Tageszeit.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: activeMeds.length,
      itemBuilder: (context, index) {
        final med = activeMeds[index];
        final dose = getDose(med);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: med.hasChanged
                ? BorderSide(color: highlightColor, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: med.hasChanged
                  ? highlightColor.withOpacity(0.15)
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.medication,
                color: med.hasChanged ? highlightColor : Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    med.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (med.hasChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Geändert',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Dosis: $dose ${med.unit} (${med.dosage})'),
                if (med.instructions.isNotEmpty)
                  Text(
                    'Hinweis: ${med.instructions}',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'EAN abgleichen',
              onPressed: () => _openEanScanDialog(existingMed: med),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView(Color highlightColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHigh),
            columns: const [
              DataColumn(label: Text('Wirkstoff / Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Stärke', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Morgens', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Mittags', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Abends', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nachts', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Einheit', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Hinweise', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Scan', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _medications.map((med) {
              final rowColor = med.hasChanged ? highlightColor.withOpacity(0.08) : null;

              return DataRow(
                color: WidgetStateProperty.all(rowColor),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (med.hasChanged) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.warning_amber_rounded, size: 16, color: highlightColor),
                        ],
                      ],
                    ),
                  ),
                  DataCell(Text(med.dosage)),
                  DataCell(Text(med.morning)),
                  DataCell(Text(med.noon)),
                  DataCell(Text(med.evening)),
                  DataCell(Text(med.night)),
                  DataCell(Text(med.unit)),
                  DataCell(Text(med.instructions)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () => _openEanScanDialog(existingMed: med),
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
}