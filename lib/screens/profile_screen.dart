import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = const UserProfile();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await ProfileService.getProfile();
    setState(() {
      _profile = loaded;
      _isLoading = false;
    });
  }

  void _openEditDialog() {
    final nameCtrl = TextEditingController(text: _profile.name);
    final dobCtrl = TextEditingController(text: _profile.dateOfBirth);
    final phoneCtrl = TextEditingController(text: _profile.phone);
    final emailCtrl = TextEditingController(text: _profile.email);
    final insuranceCtrl = TextEditingController(text: _profile.insurance);
    final insuranceNumCtrl = TextEditingController(text: _profile.insuranceNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stammdaten bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vollständiger Name',
                  icon: Icon(Icons.person),
                ),
              ),
              TextField(
                controller: dobCtrl,
                decoration: const InputDecoration(
                  labelText: 'Geburtsdatum (z.B. 01.01.1980)',
                  icon: Icon(Icons.cake),
                ),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefonnummer',
                  icon: Icon(Icons.phone),
                ),
              ),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-Mail-Adresse',
                  icon: Icon(Icons.email),
                ),
              ),
              TextField(
                controller: insuranceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Krankenkasse',
                  icon: Icon(Icons.medical_information),
                ),
              ),
              TextField(
                controller: insuranceNumCtrl,
                decoration: const InputDecoration(
                  labelText: 'Versichertennummer',
                  icon: Icon(Icons.badge),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newProfile = UserProfile(
                name: nameCtrl.text.trim(),
                dateOfBirth: dobCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                insurance: insuranceCtrl.text.trim(),
                insuranceNumber: insuranceNumCtrl.text.trim(),
              );
              await ProfileService.saveProfile(newProfile);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stammdaten erfolgreich gespeichert!')),
                );
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil & Stammdaten'),
        backgroundColor: Colors.teal.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Daten bearbeiten',
            onPressed: _openEditDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  color: Colors.teal,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Diese Daten werden automatisch für Terminanfragen und E-Mail-Exporte verwendet.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoTile('Name', _profile.name, Icons.person),
                _buildInfoTile('Geburtsdatum', _profile.dateOfBirth, Icons.cake),
                _buildInfoTile('Telefonnummer', _profile.phone, Icons.phone),
                _buildInfoTile('E-Mail-Adresse', _profile.email, Icons.email),
                _buildInfoTile('Krankenkasse', _profile.insurance, Icons.medical_information),
                _buildInfoTile('Versichertennummer', _profile.insuranceNumber, Icons.badge),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openEditDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Stammdaten anpassen'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value.isNotEmpty ? value : 'Nicht angegeben',
          style: TextStyle(
            fontSize: 16,
            fontWeight: value.isNotEmpty ? FontWeight.bold : FontWeight.normal,
            color: value.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}