class Treatment {
  int? id;

  int patientId;
  int medicineId;

  DateTime startDate;
  DateTime endDate;

  int frequencyHours;

  double doseAmount;
  String doseUnit;

  int totalDoses;

  bool active;

  Treatment({
    this.id,
    required this.patientId,
    required this.medicineId,
    required this.startDate,
    required this.endDate,
    required this.frequencyHours,
    required this.doseAmount,
    required this.doseUnit,
    required this.totalDoses,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'medicineId': medicineId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'frequencyHours': frequencyHours,
      'doseAmount': doseAmount,
      'doseUnit': doseUnit,
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
      endDate: DateTime.parse(map['endDate']),
      frequencyHours: map['frequencyHours'],
      doseAmount: (map['doseAmount'] as num).toDouble(),
      doseUnit: map['doseUnit'],
      totalDoses: map['totalDoses'],
      active: map['active'] == 1,
    );
  }
}
