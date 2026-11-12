class DoseHistory {
  int? id;

  int patientId;
  int treatmentId;

  DateTime scheduledDateTime;
  DateTime? administeredDateTime;

  String status;

  // Datos obtenidos mediante JOIN
  String? patientName;
  String? medicineName;

  double? doseAmount;
  String? doseUnit;

  DoseHistory({
    this.id,
    required this.patientId,
    required this.treatmentId,
    required this.scheduledDateTime,
    this.administeredDateTime,
    required this.status,
    this.patientName,
    this.medicineName,
    this.doseAmount,
    this.doseUnit,
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

      // Campos opcionales provenientes de JOIN
      patientName: map['patientName'],
      medicineName: map['medicineName'],
      doseAmount: map['doseAmount'] != null
          ? (map['doseAmount'] as num).toDouble()
          : null,
      doseUnit: map['doseUnit'],
    );
  }
}
