class DoseHistory {
  int? id;

  int patientId;

  int treatmentId;

  DateTime scheduledTime;

  DateTime? administeredTime;

  bool administered;

  DoseHistory({
    this.id,
    required this.patientId,
    required this.treatmentId,
    required this.scheduledTime,
    this.administeredTime,
    this.administered = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'treatmentId': treatmentId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'administeredTime': administeredTime?.toIso8601String(),
      'administered': administered ? 1 : 0,
    };
  }

  factory DoseHistory.fromMap(Map<String, dynamic> map) {
    return DoseHistory(
      id: map['id'],
      patientId: map['patientId'],
      treatmentId: map['treatmentId'],
      scheduledTime: DateTime.parse(map['scheduledTime']),
      administeredTime: map['administeredTime'] != null
          ? DateTime.parse(map['administeredTime'])
          : null,
      administered: map['administered'] == 1,
    );
  }
}
