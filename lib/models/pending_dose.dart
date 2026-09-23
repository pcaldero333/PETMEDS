class PendingDose {
  int? id;

  int treatmentId;
  int patientId;

  DateTime scheduledDateTime;
  DateTime alarmDateTime;

  String status;

  PendingDose({
    this.id,
    required this.treatmentId,
    required this.patientId,
    required this.scheduledDateTime,
    required this.alarmDateTime,
    this.status = 'PENDING',
  });

  // ============================================================
  // CONVERTIR OBJETO A MAPA
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'treatmentId': treatmentId,
      'patientId': patientId,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'alarmDateTime': alarmDateTime.toIso8601String(),
      'status': status,
    };
  }

  // ============================================================
  // CREAR OBJETO DESDE MAPA
  // ============================================================

  factory PendingDose.fromMap(Map<String, dynamic> map) {
    return PendingDose(
      id: map['id'],
      treatmentId: map['treatmentId'],
      patientId: map['patientId'],
      scheduledDateTime: DateTime.parse(map['scheduledDateTime']),
      alarmDateTime: DateTime.parse(map['alarmDateTime']),
      status: map['status'] ?? 'PENDING',
    );
  }

  // ============================================================
  // COPIAR OBJETO CAMBIANDO ALGUNOS VALORES
  // ============================================================

  PendingDose copyWith({
    int? id,
    int? treatmentId,
    int? patientId,
    DateTime? scheduledDateTime,
    DateTime? alarmDateTime,
    String? status,
  }) {
    return PendingDose(
      id: id ?? this.id,
      treatmentId: treatmentId ?? this.treatmentId,
      patientId: patientId ?? this.patientId,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      alarmDateTime: alarmDateTime ?? this.alarmDateTime,
      status: status ?? this.status,
    );
  }
}
