class Doctor {
  final int? id;
  final String name;
  final String specialty;
  final String address;
  final String phone;
  final String email;
  final String openingHours;
  final String? appointmentUrl;
  final String? placeId;
  final String? lastUpdated;

  Doctor({
    this.id,
    required this.name,
    required this.specialty,
    required this.address,
    required this.phone,
    required this.email,
    required this.openingHours,
    this.appointmentUrl,
    this.placeId,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'address': address,
      'phone': phone,
      'email': email,
      'openingHours': openingHours,
      'appointmentUrl': appointmentUrl,
      'placeId': placeId,
      'lastUpdated': lastUpdated,
    };
  }

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: map['id'],
      name: map['name'],
      specialty: map['specialty'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      openingHours: map['openingHours'] ?? '',
      appointmentUrl: map['appointmentUrl'],
      placeId: map['placeId'],
      lastUpdated: map['lastUpdated'],
    );
  }

  // Optional: Nützlich beim Bearbeiten von Einträgen
  Doctor copyWith({
    int? id,
    String? name,
    String? specialty,
    String? address,
    String? phone,
    String? email,
    String? openingHours,
    String? appointmentUrl,
    String? placeId,
    String? lastUpdated,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      openingHours: openingHours ?? this.openingHours,
      appointmentUrl: appointmentUrl ?? this.appointmentUrl,
      placeId: placeId ?? this.placeId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}