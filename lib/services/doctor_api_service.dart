import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/doctor.dart';
import 'database_service.dart';

class DoctorApiService {
  static const String _apiKey = 'DEIN_GOOGLE_PLACES_API_KEY';

  static Future<Doctor> refreshDoctorDetails(Doctor doctor) async {
    if (doctor.placeId == null || doctor.placeId!.isEmpty) {
      return doctor;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=${doctor.placeId}&fields=formatted_phone_number,formatted_address,opening_hours&language=de&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['result'];

        final newAddress = data['formatted_address'] ?? doctor.address;
        final newPhone = data['formatted_phone_number'] ?? doctor.phone;

        String newHours = doctor.openingHours;
        if (data['opening_hours'] != null && data['opening_hours']['weekday_text'] != null) {
          newHours = (data['opening_hours']['weekday_text'] as List).join('\n');
        }

        final updatedDoctor = Doctor(
          id: doctor.id,
          name: doctor.name,
          specialty: doctor.specialty,
          address: newAddress,
          phone: newPhone,
          email: doctor.email,
          openingHours: newHours,
          appointmentUrl: doctor.appointmentUrl,
          placeId: doctor.placeId,
          lastUpdated: DateTime.now().toIso8601String().split('T')[0],
        );

        await DatabaseService.instance.updateDoctor(updatedDoctor);
        return updatedDoctor;
      }
    } catch (_) {}
    return doctor;
  }
}