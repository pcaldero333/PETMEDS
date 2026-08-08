class Treatment {
  int? id;

  int patientId;
  int medicineId;

  DateTime startDate;

  int frequencyHours;

  DateTime endDate;

  int totalDoses;

  bool active;

  Treatment({
    this.id,
    required this.patientId,
    required this.medicineId,
    required this.startDate,
    required this.frequencyHours,
    required this.endDate,
    required this.totalDoses,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'medicineId': medicineId,
      'startDate': startDate.toIso8601String(),
      'frequencyHours': frequencyHours,
      'endDate': endDate.toIso8601String(),
      'totalDoses': totalDoses,
      'active': active ? 1 : 0,
    };
  }

  factory Treatment.fromMap(Map<String, dynamic> map) {
    return Treatment(
      id: map['id'],
      patientId: map['patientId'],
      medicineId: map['medicineId'],
      startDate: DateTime.parse(map['startDate']),
      frequencyHours: map['frequencyHours'],
      endDate: DateTime.parse(map['endDate']),
      totalDoses: map['totalDoses'],
      active: map['active'] == 1,
    );
  }
}
