class Medicine {
  int? id;

  String name;
  String presentation;
  String concentration;
  String observations;

  Medicine({
    this.id,
    required this.name,
    required this.presentation,
    required this.concentration,
    required this.observations,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'presentation': presentation,
      'concentration': concentration,
      'observations': observations,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      presentation: map['presentation'],
      concentration: map['concentration'],
      observations: map['observations'],
    );
  }
}
