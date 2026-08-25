import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/doctor.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  bool _isGridView = true;
  final List<Doctor> _doctors = [];

  // Hilfsfunktionen für Anrufe, E-Mails und Webseiten
  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte $phoneNumber nicht anrufen.')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte E-Mail-App für $email nicht öffnen.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte URL $urlString nicht öffnen.')),
      );
    }
  }

  // Simulation / Anbindung für die automatische Arztsuche
  Future<Map<String, String>?> _autoSearchDoctor(String name, String city) async {
    // Hier kann die Anbindung an die Google Places API oder ein Backend erfolgen.
    await Future.delayed(const Duration(seconds: 2)); // Simuliert Netzwerkanfrage

    if (name.isEmpty) return null;

    // Beispiel-Ergebnis zur Veranschaulichung der automatischen Befüllung:
    return {
      'specialty': 'Allgemeinmedizin',
      'address': city.isNotEmpty ? 'Musterstraße 12, $city' : 'Musterstraße 12',
      'phone': '+49 89 1234567',
      'email': 'praxis@beispiel-arzt.de',
      'openingHours': 'Mo-Fr 08:00 - 12:00 Uhr',
      'appointmentUrl': 'https://www.doctolib.de',
    };
  }

  void _addDoctor(Doctor doctor) {
    setState(() {
      _doctors.add(doctor);
    });
  }

  void _deleteDoctor(int id) {
    setState(() {
      _doctors.removeWhere((doc) => doc.id == id);
    });
  }

  void _showAddDoctorDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final cityController = TextEditingController();
    final specialtyController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final openingHoursController = TextEditingController();
    final appointmentUrlController = TextEditingController();

    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Neuen Arzt hinzufügen'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name / Praxis *',
                          icon: Icon(Icons.person),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Bitte geben Sie einen Namen ein';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: cityController,
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
                        onPressed: isSearching
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final city = cityController.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bitte zuerst Praxis/Name eingeben.'),
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() => isSearching = true);

                                final data = await _autoSearchDoctor(name, city);

                                setDialogState(() {
                                  isSearching = false;
                                  if (data != null) {
                                    specialtyController.text = data['specialty'] ?? '';
                                    addressController.text = data['address'] ?? '';
                                    phoneController.text = data['phone'] ?? '';
                                    emailController.text = data['email'] ?? '';
                                    openingHoursController.text = data['openingHours'] ?? '';
                                    appointmentUrlController.text = data['appointmentUrl'] ?? '';
                                  }
                                });
                              },
                        icon: isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(isSearching ? 'Suche läuft...' : 'Daten automatisch suchen'),
                      ),
                      const Divider(height: 24),
                      TextFormField(
                        controller: specialtyController,
                        decoration: const InputDecoration(
                          labelText: 'Fachrichtung',
                          icon: Icon(Icons.medical_services),
                        ),
                      ),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          icon: Icon(Icons.location_on),
                        ),
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefonnummer',
                          icon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-Mail',
                          icon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextFormField(
                        controller: openingHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Öffnungszeiten',
                          icon: Icon(Icons.access_time),
                        ),
                      ),
                      TextFormField(
                        controller: appointmentUrlController,
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
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final newDoctor = Doctor(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: nameController.text.trim(),
                        specialty: specialtyController.text.trim(),
                        address: addressController.text.trim(),
                        phone: phoneController.text.trim(),
                        email: emailController.text.trim(),
                        openingHours: openingHoursController.text.trim(),
                        appointmentUrl: appointmentUrlController.text.trim().isEmpty
                            ? null
                            : appointmentUrlController.text.trim(),
                      );
                      _addDoctor(newDoctor);
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ärzte & Kontakte'),
        backgroundColor: Colors.teal.shade100,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'Zur Listenansicht' : 'Zur Visitenkartenansicht',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: _doctors.isEmpty
          ? const Center(
              child: Text(
                'Keine Ärzte eingetragen.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : _isGridView
              ? _buildBusinessCardGrid()
              : _buildListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDoctorDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Arzt hinzufügen', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBusinessCardGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisExtent: 220,
        mainAxisSpacing: 12,
      ),
      itemCount: _doctors.length,
      itemBuilder: (ctx, index) {
        final doc = _doctors[index];
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
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 6),
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

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _doctors.length,
      itemBuilder: (ctx, index) {
        final doc = _doctors[index];
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