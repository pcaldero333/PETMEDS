class Patient {
  int? id;

  String name;
  String species;
  String breed;

  String? sex;
  DateTime? birthDate;
  double? weight;

  String ownerName;
  String ownerPhone;

  String? notes;
  String? photoPath;

  Patient({
    this.id,
    required this.name,
    required this.species,
    required this.breed,
    this.sex,
    this.birthDate,
    this.weight,
    required this.ownerName,
    required this.ownerPhone,
    this.notes,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'sex': sex,
      'birthDate': birthDate?.toIso8601String(),
      'weight': weight,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'notes': notes,
      'photoPath': photoPath,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'],
      name: map['name'],
      species: map['species'],
      breed: map['breed'],
      sex: map['sex'],
      birthDate: map['birthDate'] != null
          ? DateTime.parse(map['birthDate'])
          : null,
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
      ownerName: map['ownerName'] ?? '',
      ownerPhone: map['ownerPhone'] ?? '',
      notes: map['notes'],
      photoPath: map['photoPath'],
    );
  }
}
