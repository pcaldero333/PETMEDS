class DoseHistory {
  int? id;

  int patientId;
  int treatmentId;

  DateTime scheduledDateTime;
  DateTime? administeredDateTime;

  String status;

  DoseHistory({
    this.id,
    required this.patientId,
    required this.treatmentId,
    required this.scheduledDateTime,
    this.administeredDateTime,
    required this.status,
  });

  // ============================================================
  // CONVERTIR OBJETO A MAPA
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'treatmentId': treatmentId,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'administeredDateTime': administeredDateTime?.toIso8601String(),
      'status': status,
    };
  }

  // ============================================================
  // CREAR OBJETO DESDE MAPA
  // ============================================================

  factory DoseHistory.fromMap(Map<String, dynamic> map) {
    return DoseHistory(
      id: map['id'],
      patientId: map['patientId'],
      treatmentId: map['treatmentId'],
      scheduledDateTime: DateTime.parse(map['scheduledDateTime']),
      administeredDateTime: map['administeredDateTime'] != null
          ? DateTime.parse(map['administeredDateTime'])
          : null,
      status: map['status'] ?? 'UNKNOWN',
    );
  }
}
