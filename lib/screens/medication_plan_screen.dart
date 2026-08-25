import 'package:flutter/material.dart';

class MedicationItem {
  final String id;
  final String name;
  final String dosage;
  final String timeOfDay;
  final String note;
  final String ean;
  final bool isVerified;
  final bool hasChanged;
  final String? changeWarning;

  const MedicationItem({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timeOfDay,
    this.note = '',
    this.ean = '',
    this.isVerified = false,
    this.hasChanged = false,
    this.changeWarning,
  });

  MedicationItem copyWith({
    String? id,
    String? name,
    String? dosage,
    String? timeOfDay,
    String? note,
    String? ean,
    bool? isVerified,
    bool? hasChanged,
    String? changeWarning,
  }) {
    return MedicationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      note: note ?? this.note,
      ean: ean ?? this.ean,
      isVerified: isVerified ?? this.isVerified,
      hasChanged: hasChanged ?? this.hasChanged,
      changeWarning: changeWarning ?? this.changeWarning,
    );
  }
}

enum ViewMode { table, tabs }

class MedicationPlanScreen extends StatefulWidget {
  const MedicationPlanScreen({super.key});

  @override
  State<MedicationPlanScreen> createState() => _MedicationPlanScreenState();
}

class _MedicationPlanScreenState extends State<MedicationPlanScreen>
    with SingleTickerProviderStateMixin {
  ViewMode _currentView = ViewMode.tabs;
  late TabController _tabController;

  final List<String> _timeCategories = [
    'Vormittag',
    'Mittag',
    'Nachmittag',
    'Abend',
  ];

  final Map<String, Map<String, String>> _mockDatabase = {
    '4012345678901': {'name': 'Ramipril 5mg', 'activeIngredient': 'Ramipril'},
    '4098765432109': {'name': 'Pantoprazol 20mg', 'activeIngredient': 'Pantoprazol'},
    '4055555123456': {'name': 'Ibuprofen 400mg', 'activeIngredient': 'Ibuprofen'},
  };

  final List<MedicationItem> _medications = [
    const MedicationItem(
      id: '1',
      name: 'Ramipril',
      dosage: '10 mg (ERHÖHT)',
      timeOfDay: 'Vormittag',
      note: 'Vor dem Frühstück mit Wasser',
      ean: '4012345678901',
      isVerified: true,
      hasChanged: true,
      changeWarning: 'Dosis vom Arzt auf 10mg erhöht!',
    ),
    const MedicationItem(
      id: '2',
      name: 'Vitamin D3',
      dosage: '1000 I.E.',
      timeOfDay: 'Vormittag',
      note: 'Zum Frühstück einnehmen',
      ean: '4022222333344',
      isVerified: false,
      hasChanged: false,
    ),
    const MedicationItem(
      id: '3',
      name: 'Ibuprofen',
      dosage: '400 mg',
      timeOfDay: 'Mittag',
      note: 'Bei Bedarf nach dem Essen',
      ean: '4055555123456',
      isVerified: true,
      hasChanged: false,
    ),
    const MedicationItem(
      id: '4',
      name: 'Magnesium',
      dosage: '300 mg',
      timeOfDay: 'Nachmittag',
      note: 'Mit viel Flüssigkeit',
      ean: '4077777888899',
      isVerified: true,
      hasChanged: true,
      changeWarning: 'Neuer Hersteller: Ratiopharm',
    ),
    const MedicationItem(
      id: '5',
      name: 'Pantoprazol',
      dosage: '20 mg',
      timeOfDay: 'Abend',
      note: '30 Min. vor dem Abendessen',
      ean: '4098765432109',
      isVerified: true,
      hasChanged: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _timeCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MedicationItem> _getMedsForCategory(String category) {
    return _medications.where((m) => m.timeOfDay == category).toList();
  }

  void _openEanScanDialog([MedicationItem? existingMed]) {
    final eanCtrl = TextEditingController(text: existingMed?.ean ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.teal, size: 28),
            SizedBox(width: 10),
            Text('Barcode scannen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Code der Packung scannen oder eingeben:',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: eanCtrl,
              style: const TextStyle(fontSize: 18),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'EAN / PZN Code',
                labelStyle: const TextStyle(fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.teal, size: 28),
                  onPressed: () => eanCtrl.text = '4012345678901',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 22),
            label: const Text('Prüfen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              final scannedEan = eanCtrl.text.trim();
              Navigator.pop(ctx);
              _verifyEanInDatabase(scannedEan, existingMed);
            },
          ),
        ],
      ),
    );
  }

  void _verifyEanInDatabase(String ean, MedicationItem? med) {
    final dbMatch = _mockDatabase[ean];

    setState(() {
      if (med != null) {
        final index = _medications.indexWhere((m) => m.id == med.id);
        if (index != -1) {
          _medications[index] = med.copyWith(ean: ean, isVerified: dbMatch != null);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: dbMatch != null ? Colors.teal.shade800 : Colors.orange.shade900,
        content: Text(
          dbMatch != null
              ? 'Erfolgreich verifiziert: ${dbMatch['name']}'
              : 'EAN nicht in Datenbank gefunden.',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyWarnings = _medications.any((m) => m.hasChanged);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9), // Sanfter Off-White Hintergrund
      appBar: AppBar(
        title: const Text(
          'Medikationsplan',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
        ),
        backgroundColor: const Color(0xFFE0F2F1), // Frisches Helltürkis
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28, color: Color(0xFF004D40)),
            tooltip: 'EAN Scannen',
            onPressed: () => _openEanScanDialog(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SegmentedButton<ViewMode>(
              segments: const [
                ButtonSegment<ViewMode>(
                  value: ViewMode.tabs,
                  icon: Icon(Icons.tab, size: 20),
                  label: Text('Tabs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                ButtonSegment<ViewMode>(
                  value: ViewMode.table,
                  icon: Icon(Icons.table_chart, size: 20),
                  label: Text('Tabelle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
              selected: {_currentView},
              onSelectionChanged: (Set<ViewMode> newSelection) {
                setState(() {
                  _currentView = newSelection.first;
                });
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasAnyWarnings) _buildGlobalWarningHeader(),
          Expanded(
            child: _currentView == ViewMode.table
                ? _buildTableView()
                : _buildTabsView(),
          ),
        ],
      ),
    );
  }

  // Warnbanner
  Widget _buildGlobalWarningHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFD81B60), // Deutliches, fröhlich-kräftiges Magenta
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Achtung: Für einige Medikamente liegen neue Einnahmehinweise vor!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. TABELLENANSICHT (Große Lesbarkeit)
  Widget _buildTableView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tagesübersicht',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
              ),
              ElevatedButton.icon(
                onPressed: () => _openEanScanDialog(),
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('EAN Abgleich', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 52,
              dataRowMaxHeight: 68,
              headingRowHeight: 48,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFB2DFDB)),
              columns: const [
                DataColumn(label: Text('Tageszeit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status / EAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Medikament', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Dosierung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Hinweis / Warnung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
              rows: _timeCategories.expand((category) {
                final meds = _getMedsForCategory(category);
                if (meds.isEmpty) {
                  return [
                    DataRow(cells: [
                      DataCell(Text(category, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                      const DataCell(Text('-')),
                      const DataCell(Text('-', style: TextStyle(color: Colors.grey))),
                      const DataCell(Text('-', style: TextStyle(color: Colors.grey))),
                      const DataCell(Text('Keine Einnahme', style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic))),
                    ])
                  ];
                }

                return meds.map((med) {
                  return DataRow(
                    color: med.hasChanged
                        ? WidgetStateProperty.all(const Color(0xFFFCE4EC))
                        : null,
                    cells: [
                      DataCell(Text(category, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                      DataCell(
                        Row(
                          children: [
                            Icon(
                              med.isVerified ? Icons.check_circle : Icons.help_outline,
                              size: 22,
                              color: med.isVerified ? Colors.teal.shade800 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              med.ean.isNotEmpty ? med.ean : 'Keine EAN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: med.isVerified ? Colors.black87 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          med.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: med.hasChanged ? const Color(0xFF880E4F) : const Color(0xFF004D40),
                          ),
                        ),
                      ),
                      DataCell(Text(med.dosage, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                      DataCell(
                        med.hasChanged
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD81B60),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  med.changeWarning ?? 'Änderung beachten!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : Text(med.note.isNotEmpty ? med.note : '-', style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  );
                });
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 2. TAB-ANSICHT (Große Karten & sympathische Symbole)
  Widget _buildTabsView() {
    return Column(
      children: [
        Material(
          color: const Color(0xFFE0F2F1),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF004D40),
            unselectedLabelColor: Colors.teal.shade800,
            indicatorColor: const Color(0xFF00796B),
            indicatorWeight: 4,
            tabs: const [
              Tab(icon: Icon(Icons.wb_twilight, size: 26), child: Text('Vormittag', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              Tab(icon: Icon(Icons.wb_sunny, size: 26), child: Text('Mittag', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              Tab(icon: Icon(Icons.sunny_snowing, size: 26), child: Text('Nachmittag', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              Tab(icon: Icon(Icons.nights_stay, size: 26), child: Text('Abend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _timeCategories.map((category) {
              final meds = _getMedsForCategory(category);
              if (meds.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.teal.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Keine Medikamente für $category.',
                        style: const TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: meds.length,
                itemBuilder: (context, index) {
                  final med = meds[index];
                  return Card(
                    elevation: med.hasChanged ? 4 : 2,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: med.hasChanged
                          ? const BorderSide(color: Color(0xFFD81B60), width: 2.5)
                          : BorderSide(color: Colors.teal.shade100, width: 1),
                    ),
                    color: med.hasChanged ? const Color(0xFFFFF0F5) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (med.hasChanged)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD81B60),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      med.changeWarning ?? 'WICHTIGE PLANÄNDERUNG!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: med.hasChanged
                                    ? const Color(0xFFF8BBD0)
                                    : const Color(0xFFE0F2F1),
                                child: Icon(
                                  med.hasChanged ? Icons.priority_high : Icons.medication,
                                  color: med.hasChanged ? const Color(0xFF880E4F) : const Color(0xFF00796B),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: med.hasChanged ? const Color(0xFF880E4F) : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Dosierung: ${med.dosage}',
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
                                    ),
                                    if (med.note.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Einnahme: ${med.note}',
                                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: med.isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: med.isVerified ? Colors.green.shade300 : Colors.amber.shade400,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            med.isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                                            size: 18,
                                            color: med.isVerified ? Colors.green.shade800 : Colors.amber.shade900,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            med.isVerified
                                                ? 'EAN: ${med.ean} (Geprüft)'
                                                : 'EAN: ${med.ean.isNotEmpty ? med.ean : 'Fehlt'} (Ungeprüft)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: med.isVerified ? Colors.green.shade900 : Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner, size: 28, color: Colors.teal),
                                tooltip: 'EAN scannen',
                                onPressed: () => _openEanScanDialog(med),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}