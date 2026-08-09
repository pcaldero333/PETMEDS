import 'package:flutter/material.dart';

import '../models/treatment.dart';
import '../models/patient.dart';
import '../models/medicine.dart';

import '../services/treatment_service.dart';
import '../services/patient_service.dart';
import '../services/medicine_service.dart';
import 'treatment_form_screen.dart';

class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({super.key});

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  final PatientService _patientService = PatientService();
  final MedicineService _medicineService = MedicineService();

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
    setState(() {
      loading = true;
    });

    final treatmentData = await _treatmentService.getTreatments();
    final patientData = await _patientService.getPatients();
    final medicineData = await _medicineService.getMedicines();

    if (!mounted) return;

    setState(() {
      treatments = treatmentData;
      patients = patientData;
      medicines = medicineData;
      loading = false;
    });
  }

  // ============================================================
  // BUSCAR MASCOTA
  // ============================================================

  String getPatientName(int patientId) {
    try {
      final patient = patients.firstWhere((p) => p.id == patientId);

      return patient.name;
    } catch (_) {
      return "Mascota desconocida";
    }
  }

  // ============================================================
  // BUSCAR MEDICAMENTO
  // ============================================================

  String getMedicineName(int medicineId) {
    try {
      final medicine = medicines.firstWhere((m) => m.id == medicineId);

      return medicine.name;
    } catch (_) {
      return "Medicamento desconocido";
    }
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // ============================================================
  // TEXTO DE FRECUENCIA
  // ============================================================

  String frequencyText(int hours) {
    if (hours == 1) {
      return "Cada 1 hora";
    }

    return "Cada $hours horas";
  }

  // ============================================================
  // ELIMINAR TRATAMIENTO
  // ============================================================

  Future<void> deleteTreatment(Treatment treatment) async {
    final patientName = getPatientName(treatment.patientId);
    final medicineName = getMedicineName(treatment.medicineId);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Eliminar tratamiento"),
          content: Text(
            "¿Está seguro de eliminar el tratamiento de "
            "$patientName con $medicineName?\n\n"
            "Esta acción no puede deshacerse.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    await _treatmentService.deleteTreatment(treatment.id!);

    await loadData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Tratamiento eliminado correctamente")),
    );
  }

  // ============================================================
  // TARJETA DEL TRATAMIENTO
  // ============================================================

  Widget treatmentCard(Treatment treatment) {
    final patientName = getPatientName(treatment.patientId);
    final medicineName = getMedicineName(treatment.medicineId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------
            // ENCABEZADO
            // ----------------------------------------------------
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.medication)),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(medicineName, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),

                Switch(
                  value: treatment.active,
                  onChanged: (value) async {
                    await _treatmentService.setTreatmentActive(
                      treatment.id!,
                      value,
                    );

                    await loadData();
                  },
                ),
              ],
            ),

            const Divider(height: 25),

            // ----------------------------------------------------
            // FECHAS
            // ----------------------------------------------------
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    "${formatDate(treatment.startDate)}"
                    " → "
                    "${formatDate(treatment.endDate)}",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------
            // FRECUENCIA
            // ----------------------------------------------------
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),

                const SizedBox(width: 10),

                Text(frequencyText(treatment.frequencyHours)),
              ],
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------
            // DOSIS
            // ----------------------------------------------------
            Row(
              children: [
                const Icon(Icons.medication_liquid, size: 20),

                const SizedBox(width: 10),

                Text(
                  "Dosis: ${treatment.doseAmount} "
                  "${treatment.doseUnit}",
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------
            // TOTAL DOSIS
            // ----------------------------------------------------
            Row(
              children: [
                const Icon(Icons.numbers, size: 20),

                const SizedBox(width: 10),

                Text("Total de dosis: ${treatment.totalDoses}"),
              ],
            ),

            const Divider(height: 25),

            // ----------------------------------------------------
            // ESTADO
            // ----------------------------------------------------
            Row(
              children: [
                Icon(
                  treatment.active ? Icons.check_circle : Icons.pause_circle,
                  size: 20,
                ),

                const SizedBox(width: 10),

                Text(
                  treatment.active
                      ? "Tratamiento activo"
                      : "Tratamiento inactivo",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: treatment.active ? Colors.green : Colors.grey,
                  ),
                ),

                const Spacer(),

                // ------------------------------------------------
                // ELIMINAR
                // ------------------------------------------------
                IconButton(
                  tooltip: "Eliminar",
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    deleteTreatment(treatment);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tratamientos"), centerTitle: true),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TreatmentFormScreen()),
          );

          if (resultado == true) {
            await loadData();
          }
        },
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : treatments.isEmpty
          ? const Center(
              child: Text(
                "No hay tratamientos registrados",
                style: TextStyle(fontSize: 18),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: treatments.length,
                itemBuilder: (context, index) {
                  return treatmentCard(treatments[index]);
                },
              ),
            ),
    );
  }
}
