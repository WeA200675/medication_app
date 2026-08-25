import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/doctor.dart';
import '../services/doctor_api_service.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  bool _isGridView = true;
  final List<Doctor> _doctors = [];
  
  // Controller und Suchbegriff für die Filterung
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  // Gibt die gefilterte Liste basierend auf dem Suchbegriff zurück
  List<Doctor> get _filteredDoctors {
    if (_searchQuery.isEmpty) {
      return _doctors;
    }
    return _doctors.where((doc) {
      final nameMatches = doc.name.toLowerCase().contains(_searchQuery);
      final specialtyMatches = doc.specialty.toLowerCase().contains(_searchQuery);
      final addressMatches = doc.address.toLowerCase().contains(_searchQuery);
      return nameMatches || specialtyMatches || addressMatches;
    }).toList();
  }

  // Hilfsfunktionen für Anrufe, E-Mails und Webseiten
  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showSnackBar('Konnte $phoneNumber nicht anrufen.');
    }
  }

  // Vordefinierte E-Mail-Vorlagen
  final List<Map<String, String>> _emailTemplates = [
    {
      'title': 'Allgemeine Anfrage',
      'subject': 'Anfrage / Anliegen',
      'body': 'Sehr geehrte Damen und Herren,\n\nich wende mich mit folgendem Anliegen an Ihre Praxis:\n\n[Bitte Text hier eingeben]\n\nMit freundlichen Grüßen,\n[Dein Name]'
    },
    {
      'title': 'Terminwunsch',
      'subject': 'Terminwunsch',
      'body': 'Sehr geehrte Damen und Herren,\n\nich möchte gerne einen Termin in Ihrer Praxis vereinbaren.\n\n[Wunschtermin / Uhrzeit angeben]\n\nMit freundlichen Grüßen,\n[Dein Name]'
    },
    {
      'title': 'Rezeptbestellung',
      'subject': 'Wiederholungsrezept',
      'body': 'Sehr geehrte Damen und Herren,\n\nich benötige ein Folgerezept für folgendes Medikament:\n\n[Medikamentenname / Dosierung]\n\nMit freundlichen Grüßen,\n[Dein Name]'
    },
  ];

  // Geänderte E-Mail-Funktion mit Vorlagen-Auswahl
  Future<void> _sendEmail(String email) async {
    // Dialog anzeigen, um eine Vorlage auszuwählen
    final selectedTemplate = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('E-Mail Vorlage wählen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _emailTemplates.length,
            itemBuilder: (context, index) {
              final template = _emailTemplates[index];
              return ListTile(
                title: Text(template['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(template['subject']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(template),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    // Wenn der Nutzer abgebrochen hat, abbrechen
    if (selectedTemplate == null) return;

    final subject = Uri.encodeComponent(selectedTemplate['subject']!);
    final body = Uri.encodeComponent(selectedTemplate['body']!);
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showSnackBar('Konnte E-Mail-App für $email nicht öffnen.');
    }
  }

  Future<void> _openUrl(String urlString) async {
    String formattedUrl = urlString.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnackBar('Konnte URL $urlString nicht öffnen.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _addDoctor(Doctor doctor) {
    setState(() => _doctors.add(doctor));
  }

  void _deleteDoctor(int id) {
    setState(() => _doctors.removeWhere((doc) => doc.id == id));
  }

  void _showAddDoctorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _AddDoctorDialog(),
    ).then((newDoctor) {
      if (newDoctor != null && newDoctor is Doctor) {
        _addDoctor(newDoctor);
      }
    });
  }

  void _confirmDelete(Doctor doctor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arzt löschen'),
        content: Text('Möchten Sie "${doctor.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (doctor.id != null) {
                _deleteDoctor(doctor.id!);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedDoctors = _filteredDoctors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ärzte & Kontakte'),
        backgroundColor: Colors.teal.shade100,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'Zur Listenansicht' : 'Zur Visitenkartenansicht',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchleiste oben
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Arzt, Fachrichtung oder Ort suchen...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // Inhaltsbereich (Grid, Liste oder Leer-Zustand)
          Expanded(
            child: _doctors.isEmpty
                ? const Center(
                    child: Text(
                      'Keine Ärzte eingetragen.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : displayedDoctors.isEmpty
                    ? const Center(
                        child: Text(
                          'Keine passenden Ärzte gefunden.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : _isGridView
                        ? _buildBusinessCardGrid(displayedDoctors)
                        : _buildListView(displayedDoctors),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDoctorDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Arzt hinzufügen', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBusinessCardGrid(List<Doctor> doctorsToDisplay) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 230,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: doctorsToDisplay.length,
      itemBuilder: (ctx, index) {
        final doc = doctorsToDisplay[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.teal.shade200, width: 1),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.teal.shade50.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.local_hospital, color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (doc.specialty.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                doc.specialty,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      tooltip: 'Arzt löschen',
                      onPressed: () => _confirmDelete(doc),
                    ),
                  ],
                ),
                const Divider(height: 16, thickness: 1),
                if (doc.address.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          doc.address,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (doc.openingHours.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          doc.openingHours,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (doc.appointmentUrl != null && doc.appointmentUrl!.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.calendar_month, color: Colors.teal, size: 20),
                        tooltip: 'Online-Termin buchen',
                        onPressed: () => _openUrl(doc.appointmentUrl!),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (doc.email.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.email_outlined, color: Colors.teal, size: 20),
                        tooltip: 'E-Mail senden',
                        onPressed: () => _sendEmail(doc.email),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (doc.phone.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _makePhoneCall(doc.phone),
                        icon: const Icon(Icons.phone, size: 14, color: Colors.teal),
                        label: Text(
                          doc.phone,
                          style: const TextStyle(fontSize: 11, color: Colors.teal),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.teal),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildListView(List<Doctor> doctorsToDisplay) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: doctorsToDisplay.length,
      itemBuilder: (ctx, index) {
        final doc = doctorsToDisplay[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.person, color: Colors.teal),
            ),
            title: Text(
              doc.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doc.specialty.isNotEmpty)
                  Text(
                    doc.specialty,
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
                  ),
                if (doc.address.isNotEmpty) Text(doc.address, style: const TextStyle(fontSize: 12)),
                if (doc.openingHours.isNotEmpty)
                  Text('Öffnungszeiten: ${doc.openingHours}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            isThreeLine: doc.openingHours.isNotEmpty || doc.address.isNotEmpty,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (doc.appointmentUrl != null && doc.appointmentUrl!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Colors.teal),
                    tooltip: 'Online-Termin',
                    onPressed: () => _openUrl(doc.appointmentUrl!),
                  ),
                if (doc.email.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.email_outlined, color: Colors.teal),
                    tooltip: 'E-Mail',
                    onPressed: () => _sendEmail(doc.email),
                  ),
                if (doc.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.teal),
                    tooltip: 'Anrufen',
                    onPressed: () => _makePhoneCall(doc.phone),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Arzt löschen',
                  onPressed: () => _confirmDelete(doc),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Ausgelagertes Stateful Widget für den Dialog zur Vermeidung von State-Lecks und Controller-Problemen
class _AddDoctorDialog extends StatefulWidget {
  const _AddDoctorDialog();

  @override
  State<_AddDoctorDialog> createState() => _AddDoctorDialogState();
}

class _AddDoctorDialogState extends State<_AddDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _appointmentUrlController = TextEditingController();

  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _specialtyController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _openingHoursController.dispose();
    _appointmentUrlController.dispose();
    super.dispose();
  }

  Future<void> _performAutoSearch() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst Praxis/Name eingeben.')),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final List<Doctor> results = await DoctorApiService.searchDoctors('$name $city'.trim());
      if (results.isNotEmpty && mounted) {
        final doc = results.first;
        setState(() {
          _specialtyController.text = doc.specialty;
          _addressController.text = doc.address;
          _phoneController.text = doc.phone;
          _emailController.text = doc.email;
          _openingHoursController.text = doc.openingHours;
          _appointmentUrlController.text = doc.appointmentUrl ?? '';
        });
      }
    } catch (e) {
      debugPrint('Fehler bei automatischer Suche: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuen Arzt hinzufügen'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name / Praxis *',
                  icon: Icon(Icons.person),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Bitte geben Sie einen Namen ein'
                    : null,
              ),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Ort / Stadt',
                  icon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                ),
                onPressed: _isSearching ? null : _performAutoSearch,
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isSearching ? 'Suche läuft...' : 'Daten automatisch suchen'),
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _specialtyController,
                decoration: const InputDecoration(
                  labelText: 'Fachrichtung',
                  icon: Icon(Icons.medical_services),
                ),
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  icon: Icon(Icons.location_on),
                ),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefonnummer',
                  icon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-Mail',
                  icon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _openingHoursController,
                decoration: const InputDecoration(
                  labelText: 'Öffnungszeiten',
                  icon: Icon(Icons.access_time),
                ),
              ),
              TextFormField(
                controller: _appointmentUrlController,
                decoration: const InputDecoration(
                  labelText: 'Online-Termin URL',
                  icon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newDoctor = Doctor(
                id: DateTime.now().millisecondsSinceEpoch,
                name: _nameController.text.trim(),
                specialty: _specialtyController.text.trim(),
                address: _addressController.text.trim(),
                phone: _phoneController.text.trim(),
                email: _emailController.text.trim(),
                openingHours: _openingHoursController.text.trim(),
                appointmentUrl: _appointmentUrlController.text.trim().isEmpty
                    ? null
                    : _appointmentUrlController.text.trim(),
              );
              Navigator.of(context).pop(newDoctor);
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}