class Drug {
  final int? id;
  final String name;
  final String activeIngredient;
  final String dosageForm;

  Drug({
    this.id,
    required this.name,
    required this.activeIngredient,
    required this.dosageForm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'activeIngredient': activeIngredient,
      'dosageForm': dosageForm,
    };
  }

  factory Drug.fromMap(Map<String, dynamic> map) {
    return Drug(
      id: map['id'],
      name: map['name'],
      activeIngredient: map['activeIngredient'],
      dosageForm: map['dosageForm'],
    );
  }
}