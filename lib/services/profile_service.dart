import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class ProfileService {
  static const String _keyName = 'user_name';
  static const String _keyDob = 'user_dob';
  static const String _keyPhone = 'user_phone';
  static const String _keyEmail = 'user_email';
  static const String _keyInsurance = 'user_insurance';
  static const String _keyInsuranceNum = 'user_insurance_num';
  static const String _secureProfileKey = 'user_profile_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Loads the profile from encrypted device storage.
  ///
  /// Legacy SharedPreferences values are migrated and removed only after the
  /// secure write succeeds.
  static Future<UserProfile> getProfile() async {
    final secureProfile = await _secureStorage.read(key: _secureProfileKey);
    if (secureProfile != null) {
      final decoded = jsonDecode(secureProfile);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Gespeichertes Profil ist beschädigt.');
      }
      final prefs = await SharedPreferences.getInstance();
      await _removeLegacyProfile(prefs);
      return _profileFromMap(decoded);
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyProfile = UserProfile(
      name: prefs.getString(_keyName) ?? '',
      dateOfBirth: prefs.getString(_keyDob) ?? '',
      phone: prefs.getString(_keyPhone) ?? '',
      email: prefs.getString(_keyEmail) ?? '',
      insurance: prefs.getString(_keyInsurance) ?? '',
      insuranceNumber: prefs.getString(_keyInsuranceNum) ?? '',
    );

    await _writeSecureProfile(legacyProfile);
    await _removeLegacyProfile(prefs);
    return legacyProfile;
  }

  /// Saves the profile in encrypted device storage.
  static Future<void> saveProfile(UserProfile profile) async {
    await _writeSecureProfile(profile);
    final prefs = await SharedPreferences.getInstance();
    await _removeLegacyProfile(prefs);
  }

  static Future<void> _writeSecureProfile(UserProfile profile) {
    return _secureStorage.write(
      key: _secureProfileKey,
      value: jsonEncode({
        'name': profile.name,
        'dateOfBirth': profile.dateOfBirth,
        'phone': profile.phone,
        'email': profile.email,
        'insurance': profile.insurance,
        'insuranceNumber': profile.insuranceNumber,
      }),
    );
  }

  static UserProfile _profileFromMap(Map<String, dynamic> map) {
    String value(String key) => map[key] is String ? map[key] as String : '';
    return UserProfile(
      name: value('name'),
      dateOfBirth: value('dateOfBirth'),
      phone: value('phone'),
      email: value('email'),
      insurance: value('insurance'),
      insuranceNumber: value('insuranceNumber'),
    );
  }

  static Future<void> _removeLegacyProfile(SharedPreferences prefs) async {
    await prefs.remove(_keyName);
    await prefs.remove(_keyDob);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyInsurance);
    await prefs.remove(_keyInsuranceNum);
  }
}
