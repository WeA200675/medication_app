import 'package:url_launcher/url_launcher.dart';
import '../models/med_plan_entry.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';

class EmailService {
  /// Hilfsmethode: Codiert Query-Parameter korrekt mit %20 statt '+' für mailto-Links
  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Hilfsmethode: Erstellt einen einheitlichen Block der Patientendaten.
  static String _buildPatientHeader(UserProfile profile) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('PATIENTENDATEN:');

    final name = profile.name.isNotEmpty ? profile.name : 'Nicht angegeben';
    buffer.writeln('• Name: $name');

    if (profile.dateOfBirth.isNotEmpty) {
      buffer.writeln('• Geburtsdatum: ${profile.dateOfBirth}');
    } else {
      buffer.writeln('• Geburtsdatum: Nicht angegeben');
    }

    if (profile.insurance.isNotEmpty) {
      buffer.writeln('• Krankenkasse: ${profile.insurance}');
    }
    if (profile.insuranceNumber.isNotEmpty) {
      buffer.writeln('• Versichertennummer: ${profile.insuranceNumber}');
    }
    if (profile.phone.isNotEmpty) {
      buffer.writeln('• Telefon: ${profile.phone}');
    }
    if (profile.email.isNotEmpty) {
      buffer.writeln('• E-Mail: ${profile.email}');
    }

    return buffer.toString();
  }

  /// Hilfsmethode: Formatiert den Geburtsdatum-Zusatz für die Betreffzeile.
  static String _buildDobSubjectSuffix(UserProfile profile) {
    if (profile.dateOfBirth.isNotEmpty) {
      return ' (geb. ${profile.dateOfBirth})';
    }
    return '';
  }

  /// Hilfsmethode zum sicheren Ausführen des mailto-Intents
  static Future<void> _launchEmailUri(Uri uri) async {
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw 'Es konnte keine E-Mail-App geöffnet werden.';
      }
    } catch (e) {
      throw 'Fehler beim Öffnen der E-Mail-App: $e';
    }
  }

  /// Versendet den Medikationsplan mit allen Patienten-Stammdaten.
  static Future<void> sendPlanViaEmail(
    List<MedPlanEntry> medPlan, {
    String recipientEmail = '',
  }) async {
    if (medPlan.isEmpty) {
      throw 'Der Medikationsplan ist leer.';
    }

    final profile = await ProfileService.getProfile();
    final patientName = profile.name.isNotEmpty ? profile.name : 'Patient/in';
    final dobSuffix = _buildDobSubjectSuffix(profile);

    final StringBuffer bodyText = StringBuffer();
    bodyText.writeln('Sehr geehrte Damen und Herren,\n');
    bodyText.writeln('anbei übersende ich Ihnen meinen aktuellen Medikationsplan.\n');
    bodyText.writeln(_buildPatientHeader(profile));
    bodyText.writeln('----------------------------------------');
    bodyText.writeln('AKTUELLES MEDIKATIONSPROFIL:');
    bodyText.writeln('----------------------------------------\n');

    for (var entry in medPlan) {
      bodyText.writeln('• ${entry.drugName}');
      bodyText.writeln('  Einnahmezeit: ${entry.time}');
      bodyText.writeln('  Dosierung: ${entry.dosage}');
      if (entry.instructions.isNotEmpty) {
        bodyText.writeln('  Hinweise: ${entry.instructions}');
      }
      bodyText.writeln();
    }

    bodyText.writeln('Für Rückfragen stehe ich Ihnen gerne zur Verfügung.\n');
    bodyText.writeln('Mit freundlichen Grüßen');
    bodyText.writeln(patientName);

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      query: _encodeQueryParameters({
        'subject': 'Medikationsplan – $patientName$dobSuffix',
        'body': bodyText.toString(),
      }),
    );

    await _launchEmailUri(emailLaunchUri);
  }

  /// Terminanfrage mit konkreten Terminvorschlägen.
  static Future<void> sendAppointmentProposal({
    required String recipientEmail,
    required String doctorName,
    required List<String> proposedDates,
  }) async {
    final profile = await ProfileService.getProfile();
    final patientName = profile.name.isNotEmpty ? profile.name : 'Patient/in';
    final dobSuffix = _buildDobSubjectSuffix(profile);

    final datesFormatted = proposedDates.map((d) => '• $d').join('\n');
    final salutation = doctorName.isNotEmpty
        ? 'Sehr geehrte(s) Praxis-Team / $doctorName'
        : 'Sehr geehrte Damen und Herren';

    final StringBuffer bodyText = StringBuffer();
    bodyText.writeln('$salutation,\n');
    bodyText.writeln('ich möchte gerne einen Termin in Ihrer Praxis vereinbaren.\n');
    bodyText.writeln('MEINE TERMINVORSCHLÄGE:');
    bodyText.writeln('$datesFormatted\n');
    bodyText.writeln('Sollte keiner dieser Termine passen, bitte ich Sie um einen passenden Alternativvorschlag.\n');
    bodyText.writeln(_buildPatientHeader(profile));
    bodyText.writeln('\nVielen Dank im Voraus.');
    bodyText.writeln('Mit freundlichen Grüßen');
    bodyText.writeln(patientName);

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      query: _encodeQueryParameters({
        'subject': 'Terminanfrage – $patientName$dobSuffix',
        'body': bodyText.toString(),
      }),
    );

    await _launchEmailUri(emailLaunchUri);
  }

  /// Allgemeine Terminanfrage.
  static Future<void> sendBlankAppointmentRequest({
    required String recipientEmail,
    required String doctorName,
  }) async {
    final profile = await ProfileService.getProfile();
    final patientName = profile.name.isNotEmpty ? profile.name : 'Patient/in';
    final dobSuffix = _buildDobSubjectSuffix(profile);

    final salutation = doctorName.isNotEmpty
        ? 'Sehr geehrte(s) Praxis-Team / $doctorName'
        : 'Sehr geehrte Damen und Herren';

    final StringBuffer bodyText = StringBuffer();
    bodyText.writeln('$salutation,\n');
    bodyText.writeln('ich benötige bitte einen nächstmöglichen Termin in Ihrer Praxis.\n');
    bodyText.writeln('Bitte teilen Sie mir mit, welche freien Termine Sie mir anbieten können.\n');
    bodyText.writeln(_buildPatientHeader(profile));
    bodyText.writeln('\nVielen Dank im Voraus.');
    bodyText.writeln('Mit freundlichen Grüßen');
    bodyText.writeln(patientName);

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      query: _encodeQueryParameters({
        'subject': 'Terminanfrage – $patientName$dobSuffix',
        'body': bodyText.toString(),
      }),
    );

    await _launchEmailUri(emailLaunchUri);
  }

  /// Anfrage für Befunde oder Arztbriefe.
  static Future<void> sendDoctorLetterRequest({
    required String recipientEmail,
    required String doctorName,
  }) async {
    final profile = await ProfileService.getProfile();
    final patientName = profile.name.isNotEmpty ? profile.name : 'Patient/in';
    final dobSuffix = _buildDobSubjectSuffix(profile);

    final salutation = doctorName.isNotEmpty
        ? 'Sehr geehrte(s) Praxis-Team / $doctorName'
        : 'Sehr geehrte Damen und Herren';

    final StringBuffer bodyText = StringBuffer();
    bodyText.writeln('$salutation,\n');
    bodyText.writeln('ich bitte um die Zusendung meiner aktuellen Befunde bzw. meines Arztbriefes.\n');
    bodyText.writeln(_buildPatientHeader(profile));
    bodyText.writeln('\nVielen Dank im Voraus.');
    bodyText.writeln('Mit freundlichen Grüßen');
    bodyText.writeln(patientName);

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      query: _encodeQueryParameters({
        'subject': 'Anforderung Befunde / Arztbrief – $patientName$dobSuffix',
        'body': bodyText.toString(),
      }),
    );

    await _launchEmailUri(emailLaunchUri);
  }
}