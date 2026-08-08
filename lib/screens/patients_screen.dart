import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import 'patient_form_screen.dart';
import 'patient_detail_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final PatientService _patientService = PatientService();

  List<Patient> patients = [];

  @override
  void initState() {
    super.initState();
    loadPatients();
  }

  Future<void> loadPatients() async {
    final data = await _patientService.getPatients();

    setState(() {
      patients = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mascotas"), centerTitle: true),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),

        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PatientFormScreen()),
          );

          await loadPatients();
        },
      ),

      body: patients.isEmpty
          ? const Center(
              child: Text(
                "No hay mascotas registradas",
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: patients.length,

              itemBuilder: (context, index) {
                final p = patients[index];

                return Card(
                  margin: const EdgeInsets.all(10),

                  child: ListTile(
                    onTap: () async {
                      final resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDetailScreen(patient: p),
                        ),
                      );

                      if (resultado == true) {
                        await loadPatients();
                      }
                    },
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: p.photoPath != null
                          ? FileImage(File(p.photoPath!))
                          : null,
                      child: p.photoPath == null
                          ? const Icon(Icons.pets)
                          : null,
                    ),

                    title: Text(p.name),

                    subtitle: Text("${p.species} - ${p.breed}"),

                    trailing: Text(p.ownerName),
                  ),
                );
              },
            ),
    );
  }
}
