import 'package:flutter/material.dart';

import '../models/treatment.dart';
import '../models/patient.dart';
import '../models/medicine.dart';

import '../services/treatment_service.dart';
import '../services/patient_service.dart';
import '../services/medicine_service.dart';

class TreatmentFormScreen extends StatefulWidget {
  final Treatment? treatment;

  const TreatmentFormScreen({super.key, this.treatment});

  @override
  State<TreatmentFormScreen> createState() => _TreatmentFormScreenState();
}

class _TreatmentFormScreenState extends State<TreatmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TreatmentService _treatmentService = TreatmentService();

  final PatientService _patientService = PatientService();

  final MedicineService _medicineService = MedicineService();

  List<Patient> patients = [];
  List<Medicine> medicines = [];

  int? selectedPatientId;
  int? selectedMedicineId;

  DateTime? startDate;
  DateTime? endDate;

  int frequencyHours = 6;

  final TextEditingController doseAmountController = TextEditingController();

  String doseUnit = "tableta";

  int totalDoses = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadData();
  }

  @override
  void dispose() {
    doseAmountController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR MASCOTAS Y MEDICAMENTOS
  // ============================================================

  Future<void> loadData() async {
    final patientData = await _patientService.getPatients();

    final medicineData = await _medicineService.getMedicines();

    if (!mounted) return;

    setState(() {
      patients = patientData;
      medicines = medicineData;

      loading = false;
    });

    // Si estamos editando un tratamiento,
    // cargar sus datos después de tener las listas.
    if (widget.treatment != null) {
      loadTreatment();
    }
  }

  // ============================================================
  // CARGAR TRATAMIENTO PARA EDICIÓN
  // ============================================================

  void loadTreatment() {
    final treatment = widget.treatment!;

    setState(() {
      selectedPatientId = treatment.patientId;
      selectedMedicineId = treatment.medicineId;

      startDate = treatment.startDate;
      endDate = treatment.endDate;

      frequencyHours = treatment.frequencyHours;

      doseAmountController.text = treatment.doseAmount.toString();

      doseUnit = treatment.doseUnit;

      totalDoses = treatment.totalDoses;
    });
  }

  // ============================================================
  // CALCULAR TOTAL DE DOSIS
  // ============================================================

  void calculateTotalDoses() {
    if (startDate == null || endDate == null) {
      return;
    }

    if (frequencyHours <= 0) {
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      setState(() {
        totalDoses = 0;
      });
      return;
    }

    final difference = endDate!.difference(startDate!);

    final hours = difference.inMinutes / 60;

    final doses = (hours / frequencyHours).floor() + 1;

    setState(() {
      totalDoses = doses;
    });
  }

  // ============================================================
  // SELECCIONAR FECHA Y HORA DE INICIO
  // ============================================================

  Future<void> selectStartDate() async {
    final initialDate = startDate ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null) {
      return;
    }

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null) {
      return;
    }

    setState(() {
      startDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });

    calculateTotalDoses();
  }

  // ============================================================
  // SELECCIONAR FECHA Y HORA FINAL
  // ============================================================

  Future<void> selectEndDate() async {
    final initialDate = endDate ?? startDate ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null) {
      return;
    }

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null) {
      return;
    }

    setState(() {
      endDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });

    calculateTotalDoses();
  }

  // ============================================================
  // FORMATEAR FECHA Y HORA
  // ============================================================

  String formatDateTime(DateTime? date) {
    if (date == null) {
      return "Seleccionar";
    }

    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // GUARDAR
  // ============================================================

  Future<void> saveTreatment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedPatientId == null) {
      showMessage("Seleccione una mascota");
      return;
    }

    if (selectedMedicineId == null) {
      showMessage("Seleccione un medicamento");
      return;
    }

    if (startDate == null) {
      showMessage("Seleccione la fecha de inicio");
      return;
    }

    if (endDate == null) {
      showMessage("Seleccione la fecha final");
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      showMessage("La fecha final no puede ser anterior a la fecha de inicio");
      return;
    }

    final doseAmount = double.tryParse(doseAmountController.text.trim());

    if (doseAmount == null || doseAmount <= 0) {
      showMessage("Ingrese una cantidad de dosis válida");
      return;
    }

    calculateTotalDoses();

    if (totalDoses <= 0) {
      showMessage("No se pudo calcular el total de dosis");
      return;
    }

    final treatment = Treatment(
      id: widget.treatment?.id,

      patientId: selectedPatientId!,

      medicineId: selectedMedicineId!,

      startDate: startDate!,

      endDate: endDate!,

      frequencyHours: frequencyHours,

      doseAmount: doseAmount,

      doseUnit: doseUnit,

      totalDoses: totalDoses,

      active: widget.treatment?.active ?? true,
    );

    if (widget.treatment == null) {
      final result = await _treatmentService.insertTreatment(treatment);

      if (result == -1) {
        showMessage(
          "No se puede guardar: ya existe un tratamiento "
          "para esta mascota y medicamento que se solapa con "
          "el período seleccionado.",
          backgroundColor: Colors.orange.shade800,
        );
        return;
      }

      if (result == -2) {
        showMessage("Ocurrió un error al guardar el tratamiento.");
        return;
      }
    } else {
      await _treatmentService.updateTreatment(treatment);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.treatment == null
              ? "Tratamiento guardado correctamente"
              : "Tratamiento actualizado correctamente",
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  // ============================================================
  // MOSTRAR MENSAJE
  // ============================================================

  void showMessage(String message, {Color backgroundColor = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.treatment == null ? "Nuevo Tratamiento" : "Editar Tratamiento",
        ),
        centerTitle: true,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : patients.isEmpty
          ? const Center(
              child: Text(
                "Primero debe registrar al menos una mascota.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : medicines.isEmpty
          ? const Center(
              child: Text(
                "Primero debe registrar al menos un medicamento.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // MASCOTA
                    // ==================================================
                    const Text(
                      "MASCOTA",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      value: selectedPatientId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Seleccione la mascota",
                      ),
                      items: patients.map((patient) {
                        return DropdownMenuItem<int>(
                          value: patient.id,
                          child: Text(patient.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedPatientId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 25),

                    // ==================================================
                    // MEDICAMENTO
                    // ==================================================
                    const Text(
                      "MEDICAMENTO",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      value: selectedMedicineId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Seleccione el medicamento",
                      ),
                      items: medicines.map((medicine) {
                        return DropdownMenuItem<int>(
                          value: medicine.id,
                          child: Text(medicine.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedMedicineId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 25),

                    // ==================================================
                    // FECHAS
                    // ==================================================
                    const Text(
                      "PERÍODO DEL TRATAMIENTO",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text("Inicio"),
                      subtitle: Text(formatDateTime(startDate)),
                      onTap: selectStartDate,
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available),
                      title: const Text("Finalización"),
                      subtitle: Text(formatDateTime(endDate)),
                      onTap: selectEndDate,
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // FRECUENCIA
                    // ==================================================
                    const Text(
                      "FRECUENCIA",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      value: frequencyHours,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Frecuencia",
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text("Cada 1 hora")),
                        DropdownMenuItem(value: 2, child: Text("Cada 2 horas")),
                        DropdownMenuItem(value: 4, child: Text("Cada 4 horas")),
                        DropdownMenuItem(value: 6, child: Text("Cada 6 horas")),
                        DropdownMenuItem(value: 8, child: Text("Cada 8 horas")),
                        DropdownMenuItem(
                          value: 12,
                          child: Text("Cada 12 horas"),
                        ),
                        DropdownMenuItem(
                          value: 24,
                          child: Text("Cada 24 horas"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          frequencyHours = value;
                        });

                        calculateTotalDoses();
                      },
                    ),

                    const SizedBox(height: 25),

                    // ==================================================
                    // DOSIS
                    // ==================================================
                    const Text(
                      "DOSIS",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: doseAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "Cantidad",
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Ingrese la cantidad";
                              }

                              final number = double.tryParse(value.trim());

                              if (number == null || number <= 0) {
                                return "Cantidad inválida";
                              }

                              return null;
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: doseUnit,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "Unidad",
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: "tableta",
                                child: Text("Tableta"),
                              ),
                              DropdownMenuItem(
                                value: "cápsula",
                                child: Text("Cápsula"),
                              ),
                              DropdownMenuItem(value: "ml", child: Text("ml")),
                              DropdownMenuItem(value: "mg", child: Text("mg")),
                              DropdownMenuItem(
                                value: "gota",
                                child: Text("Gota"),
                              ),
                              DropdownMenuItem(
                                value: "unidad",
                                child: Text("Unidad"),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                doseUnit = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // ==================================================
                    // TOTAL DOSIS
                    // ==================================================
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.calculate, size: 30),

                            const SizedBox(width: 15),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "TOTAL DE DOSIS",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "$totalDoses dosis",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // GUARDAR
                    // ==================================================
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(
                          widget.treatment == null
                              ? "Guardar tratamiento"
                              : "Actualizar tratamiento",
                          style: const TextStyle(fontSize: 17),
                        ),
                        onPressed: saveTreatment,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
