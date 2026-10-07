import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/doctor.dart';
import 'database_service.dart';

class DoctorApiService {
  static const Map<String, String> _headers = {
    'User-Agent': 'medication_app/1.0 (https://github.com/WeA200675/medication_app)',
    'Accept': 'application/json',
  };

  /// Searches OpenStreetMap's Nominatim service. Search terms are sent to that
  /// public service, so do not include patient names or other identifying data.
  static Future<List<Doctor>> searchDoctors(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return [];

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': normalizedQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'extratags': '1',
        'limit': '15',
        'accept-language': 'de',
      },
    );

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => _doctorFromNominatim(
                Map<String, dynamic>.from(item),
                normalizedQuery,
              ))
          .toList();
    } catch (_) {
      // Search is optional; callers can present an empty result and allow
      // manual doctor entry when the service is unavailable.
      return [];
    }
  }

  static Doctor _doctorFromNominatim(
    Map<String, dynamic> item,
    String fallbackName,
  ) {
    final rawAddress = item['address'];
    final address = rawAddress is Map ? rawAddress : const <String, dynamic>{};
    final rawExtras = item['extratags'];
    final extras = rawExtras is Map ? rawExtras : const <String, dynamic>{};

    String valueFrom(Map values, List<String> keys) {
      for (final key in keys) {
        final value = values[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    final road = valueFrom(address, ['road', 'pedestrian']);
    final houseNumber = valueFrom(address, ['house_number']);
    final postcode = valueFrom(address, ['postcode']);
    final city = valueFrom(address, ['city', 'town', 'village']);
    final addressParts = [
      [road, houseNumber].where((part) => part.isNotEmpty).join(' '),
      [postcode, city].where((part) => part.isNotEmpty).join(' '),
    ].where((part) => part.isNotEmpty);
    final displayName = item['display_name'] is String
        ? item['display_name'] as String
        : '';

    return Doctor(
      placeId: item['place_id']?.toString() ?? '',
      name: displayName.split(',').first.trim().isNotEmpty
          ? displayName.split(',').first.trim()
          : (item['name'] is String ? item['name'] as String : fallbackName),
      specialty: valueFrom(extras, ['healthcare:speciality', 'amenity'])
          .ifEmpty('Facharzt / Praxis'),
      address: addressParts.join(', ').ifEmpty(displayName),
      phone: valueFrom(extras, ['phone', 'contact:phone']),
      email: valueFrom(extras, ['email', 'contact:email']),
      openingHours: valueFrom(extras, ['opening_hours']),
      appointmentUrl: valueFrom(extras, ['website', 'contact:website']),
      lastUpdated: DateTime.now().toIso8601String().split('T').first,
    );
  }

  /// Refreshes a saved doctor's details and optionally looks for a public email
  /// address on the practice website.
  static Future<Doctor> refreshDoctorDetails(Doctor doctor) async {
    final website = doctor.appointmentUrl?.trim() ?? '';
    final newEmail = doctor.email.isNotEmpty || website.isEmpty
        ? doctor.email
        : await _extractEmailFromWebsite(website);

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
      lastUpdated: DateTime.now().toIso8601String().split('T').first,
    );

    await DatabaseService.instance.updateDoctor(updatedDoctor);
    return updatedDoctor;
  }

  static Future<String> _extractEmailFromWebsite(String websiteUrl) async {
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );

    try {
      final uri = Uri.parse(websiteUrl);
      if (uri.scheme != 'https' || uri.host.isEmpty) return '';

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final match = emailRegex.firstMatch(response.body);
        if (match != null) return match.group(0)!;
      }

      final impressumUri = uri.replace(path: '/impressum', query: null, fragment: null);
      final impressumResponse = await http
          .get(impressumUri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (impressumResponse.statusCode == 200) {
        final match = emailRegex.firstMatch(impressumResponse.body);
        if (match != null) return match.group(0)!;
      }
    } catch (_) {
      // The address remains editable and can be entered manually.
    }
    return '';
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
