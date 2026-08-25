import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/doctor.dart';
import 'database_service.dart';

class DoctorApiService {
  // Benutzerdefinierter User-Agent (Vorgabe von OpenStreetMap/Nominatim)
  static const Map<String, String> _headers = {
    'User-Agent': 'ArztVerwaltungApp/1.0 (kontakt@beispiel.de)'
  };

  /// 1. Kostenlose Arztsuche via OpenStreetMap (Nominatim)
  static Future<List<Doctor>> searchDoctors(String query) async {
    print('--> searchDoctors aufgerufen mit Query: "$query"');

    if (query.trim().length < 2) {
      print('--> Query zu kurz (< 2 Zeichen), wird übersprungen.');
      return [];
    }

    // Suchbegriff direkt 1:1 übernehmen, ohne künstliche Anhänge wie "Arzt"
    final finalQuery = query.trim();

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(finalQuery)}'
      '&format=json'
      '&addressdetails=1'
      '&extratags=1'
      '&limit=15'
      '&accept-language=de',
    );

    try {
      print('Sende Anfrage an: $url');
      final response = await http.get(url, headers: _headers);

      print('OSM Status Code: ${response.statusCode}');
      print('OSM Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded.map((item) {
            final address = item['address'] ?? {};
            final extra = item['extratags'] ?? {};

            // Adresse zusammenbauen
            final road = address['road'] ?? address['pedestrian'] ?? '';
            final houseNumber = address['house_number'] ?? '';
            final postCode = address['postcode'] ?? '';
            final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
            final fullAddress = '$road $houseNumber, $postCode $city'.trim();

            // Kontaktdaten aus OpenStreetMap Extratags auslesen (falls vorhanden)
            final phone = extra['phone'] ?? extra['contact:phone'] ?? '';
            final email = extra['email'] ?? extra['contact:email'] ?? '';
            final website = extra['website'] ?? extra['contact:website'] ?? '';
            final openingHours = extra['opening_hours'] ?? '';

            return Doctor(
              placeId: item['place_id']?.toString() ?? '',
              name: item['display_name']?.split(',').first ?? item['name'] ?? query,
              specialty: extra['healthcare:speciality'] ?? extra['amenity'] ?? 'Facharzt / Praxis',
              address: fullAddress.isNotEmpty ? fullAddress : item['display_name'] ?? '',
              phone: phone,
              email: email,
              openingHours: openingHours,
              appointmentUrl: website,
              lastUpdated: DateTime.now().toIso8601String().split('T')[0],
            );
          }).toList();
        } else {
          print('Achtung: OSM hat keine Liste zurückgegeben, sondern: $decoded');
        }
      }
    } catch (e, stackTrace) {
      print('Fehler bei OpenStreetMap-Suche: $e');
      print(stackTrace);
    }
    return [];
  }

  /// 2. Details aktualisieren & E-Mail von Website scrapen (optional)
  static Future<Doctor> refreshDoctorDetails(Doctor doctor) async {
    if (doctor.appointmentUrl == null || doctor.appointmentUrl!.isEmpty) {
      return doctor;
    }

    String newEmail = doctor.email;
    if (newEmail.isEmpty) {
      newEmail = await _extractEmailFromWebsite(doctor.appointmentUrl!);
    }

    final updatedDoctor = Doctor(
      id: doctor.id,
      name: doctor.name,
      specialty: doctor.specialty,
      address: doctor.address,
      phone: doctor.phone,
      email: newEmail,
      openingHours: doctor.openingHours,
      appointmentUrl: doctor.appointmentUrl,
      placeId: doctor.placeId,
      lastUpdated: DateTime.now().toIso8601String().split('T')[0],
    );

    await DatabaseService.instance.updateDoctor(updatedDoctor);
    return updatedDoctor;
  }

  /// 3. Web-Crawler & RegEx-Extraktor für E-Mail-Adressen von Praxis-Webseiten
  static Future<String> _extractEmailFromWebsite(String websiteUrl) async {
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );

    try {
      final uri = Uri.parse(websiteUrl);
      
      // Hauptseite abfragen
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final match = emailRegex.firstMatch(response.body);
        if (match != null) return match.group(0)!;
      }

      // Impressum-Unterseite abfragen
      final impressumUri = uri.replace(path: '/impressum');
      final impResponse = await http.get(impressumUri, headers: _headers).timeout(const Duration(seconds: 4));
      if (impResponse.statusCode == 200) {
        final match = emailRegex.firstMatch(impResponse.body);
        if (match != null) return match.group(0)!;
      }
    } catch (_) {}
    return '';
  }
}