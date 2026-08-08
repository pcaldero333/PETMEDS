import 'dart:io';

import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../services/patient_service.dart';
import 'patient_form_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late Patient patient;
  @override
  void initState() {
    super.initState();
    patient = widget.patient;
  }

  final PatientService _patientService = PatientService();

  Future<void> loadPatient() async {
    final updated = await _patientService.getPatientById(patient.id!);

    if (updated != null) {
      setState(() {
        patient = updated;
      });
    }
  }

  Widget buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(child: Text(value.isEmpty ? "-" : value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ficha de Mascota"), centerTitle: true),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: patient.photoPath != null
                  ? FileImage(File(patient.photoPath!))
                  : null,
              child: patient.photoPath == null
                  ? const Icon(Icons.pets, size: 60)
                  : null,
            ),
            const SizedBox(height: 20),

            Text(
              patient.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 3,

              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    buildRow("Especie", patient.species),

                    buildRow("Raza", patient.breed),

                    buildRow("Propietario", patient.ownerName),

                    buildRow("Teléfono", patient.ownerPhone),

                    buildRow("Peso", patient.weight?.toString() ?? ""),

                    buildRow("Sexo", patient.sex ?? ""),

                    buildRow("Notas", patient.notes ?? ""),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Editar"),

                onPressed: () async {
                  final actualizado = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientFormScreen(patient: patient),
                    ),
                  );

                  if (actualizado == true) {
                    await loadPatient();
                  }
                },
              ),
            ),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.delete),
                label: const Text("Eliminar mascota"),
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Eliminar mascota"),
                        content: Text(
                          "¿Está seguro de eliminar a ${patient.name}?\n\nEsta acción no puede deshacerse.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancelar"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Eliminar"),
                          ),
                        ],
                      );
                    },
                  );

                  if (!mounted) return;

                  if (confirmar == true) {
                    await _patientService.deletePatient(patient.id!);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${patient.name} fue eliminado.")),
                    );

                    Navigator.pop(context, true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
