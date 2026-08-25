import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _keyName = 'user_name';
  static const String _keyDob = 'user_dob';
  static const String _keyPhone = 'user_phone';
  static const String _keyEmail = 'user_email';
  static const String _keyInsurance = 'user_insurance';
  static const String _keyInsuranceNum = 'user_insurance_num';

  /// Lädt das gespeicherte Profil von den SharedPreferences
  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString(_keyName) ?? '',
      dateOfBirth: prefs.getString(_keyDob) ?? '',
      phone: prefs.getString(_keyPhone) ?? '',
      email: prefs.getString(_keyEmail) ?? '',
      insurance: prefs.getString(_keyInsurance) ?? '',
      insuranceNumber: prefs.getString(_keyInsuranceNum) ?? '',
    );
  }

  /// Speichert das Benutzerprofil dauerhaft auf dem Gerät
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, profile.name);
    await prefs.setString(_keyDob, profile.dateOfBirth);
    await prefs.setString(_keyPhone, profile.phone);
    await prefs.setString(_keyEmail, profile.email);
    await prefs.setString(_keyInsurance, profile.insurance);
    await prefs.setString(_keyInsuranceNum, profile.insuranceNumber);
  }
}