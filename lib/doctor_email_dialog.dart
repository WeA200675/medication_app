import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailTemplate {
  final String id;
  final String title; // Stichwort im Dropdown
  final String subject;
  final String body;

  const EmailTemplate({
    required this.id,
    required this.title,
    required this.subject,
    required this.body,
  });
}

class DoctorEmailDialog extends StatefulWidget {
  final String doctorEmail;
  final List<String> currentMedications; // Optionale Übergabe der aktuellen Medikamente

  const DoctorEmailDialog({
    super.key,
    this.doctorEmail = 'praxis@facharzt-praxis.de',
    this.currentMedications = const ['Ramipril 5mg', 'Pantoprazol 20mg'],
  });

  @override
  State<DoctorEmailDialog> createState() => _DoctorEmailDialogState();
}

class _DoctorEmailDialogState extends State<DoctorEmailDialog> {
  late List<EmailTemplate> _templates;
  EmailTemplate? _selectedTemplate;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final medListString = widget.currentMedications.isNotEmpty
        ? widget.currentMedications.map((m) => '- $m').join('\n')
        : '- [Medikament Name/Dosis]';

    // Definition der Vorlagen für das Dropdown-Menü
    _templates = [
      EmailTemplate(
        id: 'rezept',
        title: 'Pillenrezept / Folgerezept bestellen',
        subject: 'Rezeptanforderung - [Ihr Name]',
        body: 'Sehr geehrtes Praxisteam,\n\n'
            'ich benötige ein Folgerezept für folgende Dauer-Medikation:\n\n'
            '$medListString\n\n'
            'Bitte stellen Sie das E-Rezept aus bzw. lassen Sie mich wissen, wann ich das Rezept abholen kann.\n\n'
            'Mit freundlichen Grüßen,\n[Ihr Name]\nGeburtsdatum: [TT.MM.JJJJ]',
      ),
      EmailTemplate(
        id: 'termin',
        title: 'Kontrolltermin vereinbaren',
        subject: 'Terminanfrage Kontrolluntersuchung - [Ihr Name]',
        body: 'Sehr geehrtes Praxisteam,\n\n'
            'ich möchte gerne einen Termin zur nächsten Routine-/Kontrolluntersuchung vereinbaren.\n\n'
            'Mögliche Zeitfenster meinerseits wären:\n'
            '- [z. B. Vormittags ab 09:00 Uhr]\n'
            '- [z. B. Dienstag oder Donnerstag]\n\n'
            'Ich freue mich über einen kurzen Terminvorschlag.\n\n'
            'Mit freundlichen Grüßen,\n[Ihr Name]\nGeburtsdatum: [TT.MM.JJJJ]',
      ),
      EmailTemplate(
        id: 'medikation',
        title: 'Rückfrage zu Medikation / Dosis',
        subject: 'Rückfrage zur Medikation - [Ihr Name]',
        body: 'Sehr geehrte(r) Frau/Herr Dr. [Name],\n\n'
            'ich habe eine kurze Rückfrage bezüglich meiner aktuellen Einnahme von:\n\n'
            '$medListString\n\n'
            'Grund der Rückfrage: [Unverträglichkeit / Dosisänderung / Wechselwirkung]\n\n'
            'Bitte um kurze Rückmeldung oder ggf. telefonischen Rückruf.\n\n'
            'Mit freundlichen Grüßen,\n[Ihr Name]\nTelefon: [Ihre Telefonnummer]',
      ),
      EmailTemplate(
        id: 'befund',
        title: 'Befund / Überweisung anfordern',
        subject: 'Anforderung von Befunden / Überweisung - [Ihr Name]',
        body: 'Sehr geehrtes Praxisteam,\n\n'
            'ich benötige eine Überweisung zum Facharzt für [Fachrichtung] bzw. die Zusendung meines aktuellen Befundes / Laborwerts.\n\n'
            'Mit freundlichen Grüßen,\n[Ihr Name]\nGeburtsdatum: [TT.MM.JJJJ]',
      ),
    ];

    // Standardmäßig erste Vorlage auswählen
    _applyTemplate(_templates.first);
  }

  void _applyTemplate(EmailTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _subjectController.text = template.subject;
      _bodyController.text = template.body;
    });
  }

  Future<void> _sendEmail() async {
    final Uri mailUri = Uri(
      scheme: 'mailto',
      path: widget.doctorEmail,
      queryParameters: {
        'subject': _subjectController.text,
        'body': _bodyController.text,
      },
    );

    try {
      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri);
        if (mounted) Navigator.pop(context);
      } else {
        _showErrorSnackBar('Keine Standard-Mail-App gefunden.');
      }
    } catch (e) {
      _showErrorSnackBar('Fehler beim Öffnen der Mail-App.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.email_outlined, color: Colors.teal, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'E-Mail an Facharzt',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dropdown-Auswahl für Vorlagen
              DropdownButtonFormField<EmailTemplate>(
                initialValue: _selectedTemplate,
                decoration: InputDecoration(
                  labelText: 'Vorlage auswählen (Stichwort)',
                  prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.teal.shade50,
                ),
                isExpanded: true,
                items: _templates.map((template) {
                  return DropdownMenuItem<EmailTemplate>(
                    value: template,
                    child: Text(
                      template.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  );
                }).toList(),
                onChanged: (EmailTemplate? newTemplate) {
                  if (newTemplate != null) {
                    _applyTemplate(newTemplate);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Empfänger (schreibgeschützt)
              TextFormField(
                initialValue: widget.doctorEmail,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Empfänger',
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Betreff (wird durch Vorlage gefüllt, aber anpassbar)
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Betreff',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // E-Mail Text (wird durch Vorlage gefüllt, aber anpassbar)
              TextFormField(
                controller: _bodyController,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: 'E-Mail Nachricht',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Aktions-Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Betreff: ${_subjectController.text}\n\n${_bodyController.text}',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text in Zwischenablage kopiert!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Kopieren'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.send),
                    label: const Text('Senden'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}