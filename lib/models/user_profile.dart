class UserProfile {
  final String name;
  final String dateOfBirth;
  final String phone;
  final String email;
  final String insurance;
  final String insuranceNumber;

  const UserProfile({
    this.name = '',
    this.dateOfBirth = '',
    this.phone = '',
    this.email = '',
    this.insurance = '',
    this.insuranceNumber = '',
  });

  /// Erstellt eine Kopie des Profils mit optional geänderten Feldern
  UserProfile copyWith({
    String? name,
    String? dateOfBirth,
    String? phone,
    String? email,
    String? insurance,
    String? insuranceNumber,
  }) {
    return UserProfile(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      insurance: insurance ?? this.insurance,
      insuranceNumber: insuranceNumber ?? this.insuranceNumber,
    );
  }
}