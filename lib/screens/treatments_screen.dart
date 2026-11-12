import 'package:flutter/material.dart';

import '../models/treatment.dart';
import '../models/patient.dart';
import '../models/medicine.dart';
import '../models/pending_dose.dart';

import '../services/treatment_service.dart';
import '../services/patient_service.dart';
import '../services/medicine_service.dart';
import '../services/pending_dose_service.dart';

import 'treatment_form_screen.dart';

class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({super.key});

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  static const Color azul = Color(0xFF163B52);
  static const Color verde = Color(0xFF287C68);
  static const Color fondo = Color(0xFFF3F7F5);

  final TreatmentService _treatmentService = TreatmentService();
  final PatientService _patientService = PatientService();
  final MedicineService _medicineService = MedicineService();
  final PendingDoseService _pendingDoseService = PendingDoseService();

  List<PendingDose> pendingDoses = [];
  List<Treatment> treatments = [];
  List<Patient> patients = [];
  List<Medicine> medicines = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ============================================================
  // CARGAR INFORMACIÓN
  // ============================================================

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final results = await Future.wait([
        _treatmentService.getTreatments(),
        _patientService.getPatients(),
        _medicineService.getMedicines(),
        _pendingDoseService.getPendingDoses(),
      ]);

      if (!mounted) return;

      setState(() {
        treatments = results[0] as List<Treatment>;
        patients = results[1] as List<Patient>;
        medicines = results[2] as List<Medicine>;
        pendingDoses = results[3] as List<PendingDose>;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible cargar los tratamientos.'),
        ),
      );
    }
  }

  // ============================================================
  // BUSCAR MASCOTA Y MEDICAMENTO
  // ============================================================

  String getPatientName(int patientId) {
    try {
      return patients.firstWhere((p) => p.id == patientId).name;
    } catch (_) {
      return 'Mascota desconocida';
    }
  }

  String getMedicineName(int medicineId) {
    try {
      return medicines.firstWhere((m) => m.id == medicineId).name;
    } catch (_) {
      return 'Medicamento desconocido';
    }
  }

  PendingDose? getPendingDoseForTreatment(int treatmentId) {
    try {
      return pendingDoses.firstWhere((dose) => dose.treatmentId == treatmentId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // FORMATO DE FECHAS
  // ============================================================

  String formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String frequencyText(int hours) {
    return hours == 1 ? 'Cada hora' : 'Cada $hours horas';
  }

  // ============================================================
  // ABRIR FORMULARIO
  // ============================================================

  Future<void> _openTreatmentForm({Treatment? treatment}) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TreatmentFormScreen()),
    );

    if (resultado == true && mounted) {
      await loadData();
    }
  }

  // ============================================================
  // ACTIVAR / DESACTIVAR TRATAMIENTO
  // ============================================================

  Future<void> _changeTreatmentStatus(Treatment treatment, bool active) async {
    try {
      await _treatmentService.setTreatmentActive(treatment.id!, active);

      if (!mounted) return;

      await loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Tratamiento activado.' : 'Tratamiento desactivado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible actualizar el tratamiento.'),
        ),
      );
    }
  }

  // ============================================================
  // ELIMINAR TRATAMIENTO
  // ============================================================

  Future<void> deleteTreatment(Treatment treatment) async {
    final patientName = getPatientName(treatment.patientId);
    final medicineName = getMedicineName(treatment.medicineId);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar tratamiento'),
          content: Text(
            '¿Deseas eliminar el tratamiento de $patientName '
            'con $medicineName?\n\n'
            'Esta acción no puede deshacerse.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await _treatmentService.deleteTreatment(treatment.id!);

      if (!mounted) return;

      await loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tratamiento eliminado correctamente.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible eliminar el tratamiento.'),
        ),
      );
    }
  }

  // ============================================================
  // INFORMACIÓN DE UNA FILA
  // ============================================================

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: verde),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: azul,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TARJETA DEL TRATAMIENTO
  // ============================================================

  Widget treatmentCard(Treatment treatment) {
    final patientName = getPatientName(treatment.patientId);
    final medicineName = getMedicineName(treatment.medicineId);
    final pendingDose = getPendingDoseForTreatment(treatment.id!);

    final statusColor = treatment.active ? verde : Colors.blueGrey;

    return Card(
      color: Colors.white,
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 15),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4EBE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENCABEZADO
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F0E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: verde,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: azul,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicineName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Switch(
                  value: treatment.active,
                  activeTrackColor: verde,
                  onChanged: (value) {
                    _changeTreatmentStatus(treatment, value);
                  },
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ESTADO
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: treatment.active
                      ? const Color(0xFFE4F0E9)
                      : const Color(0xFFEDF0F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      treatment.active
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      size: 17,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      treatment.active ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 17),
              child: Divider(height: 1),
            ),

            // DATOS DEL TRATAMIENTO
            _infoRow(
              icon: Icons.play_circle_outline,
              label: 'Inicio',
              value: formatDateTime(treatment.startDate),
            ),

            _infoRow(
              icon: Icons.event_busy_outlined,
              label: 'Finalización',
              value: formatDateTime(treatment.endDate),
            ),

            _infoRow(
              icon: Icons.alarm_outlined,
              label: 'Próxima alarma',
              value: pendingDose != null
                  ? formatDateTime(pendingDose.alarmDateTime)
                  : 'No hay dosis pendiente',
            ),

            _infoRow(
              icon: Icons.schedule_outlined,
              label: 'Frecuencia',
              value: frequencyText(treatment.frequencyHours),
            ),

            _infoRow(
              icon: Icons.medication_liquid_outlined,
              label: 'Dosis',
              value: '${treatment.doseAmount} ${treatment.doseUnit}',
            ),

            _infoRow(
              icon: Icons.numbers_outlined,
              label: 'Total de dosis',
              value: '${treatment.totalDoses}',
            ),

            const Divider(height: 15),

            // ACCIÓN DE ELIMINAR
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => deleteTreatment(treatment),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Eliminar tratamiento',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ESTADO VACÍO
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE4F0E9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: verde,
                size: 52,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Aún no hay tratamientos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azul,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Registra un tratamiento para organizar '
              'los medicamentos y sus horarios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _openTreatmentForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo tratamiento'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: azul,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Tratamientos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTreatmentForm(),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo tratamiento'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: verde))
          : treatments.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: loadData,
              color: verde,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                children: [
                  const Text(
                    'Tratamientos registrados',
                    style: TextStyle(
                      color: azul,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${treatments.length} '
                    '${treatments.length == 1 ? 'tratamiento registrado' : 'tratamientos registrados'}',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...treatments.map(treatmentCard),
                ],
              ),
            ),
    );
  }
}
