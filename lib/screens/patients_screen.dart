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
  static const Color azul = Color(0xFF163B52);
  static const Color verde = Color(0xFF287C68);
  static const Color fondo = Color(0xFFF3F7F5);

  final PatientService _patientService = PatientService();

  List<Patient> patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadPatients();
  }

  Future<void> loadPatients() async {
    try {
      final data = await _patientService.getPatients();

      if (!mounted) return;

      setState(() {
        patients = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible cargar las mascotas.')),
      );
    }
  }

  Future<void> _openPatientForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatientFormScreen()),
    );

    if (mounted) {
      await loadPatients();
    }
  }

  Future<void> _openPatientDetail(Patient patient) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
    );

    if (resultado == true && mounted) {
      await loadPatients();
    }
  }

  Widget _buildAvatar(Patient patient) {
    final path = patient.photoPath;

    if (path != null && path.isNotEmpty) {
      final file = File(path);

      if (file.existsSync()) {
        return CircleAvatar(
          radius: 32,
          backgroundColor: const Color(0xFFE4F0E9),
          backgroundImage: FileImage(file),
        );
      }
    }

    return const CircleAvatar(
      radius: 32,
      backgroundColor: Color(0xFFE4F0E9),
      child: Icon(Icons.pets, color: verde, size: 30),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    return Card(
      color: Colors.white,
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _openPatientDetail(patient),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(patient),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: azul,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${patient.species} · ${patient.breed}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    if (patient.ownerName.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: verde,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              patient.ownerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.blueGrey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: azul, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: const Icon(Icons.pets, color: verde, size: 52),
            ),
            const SizedBox(height: 22),
            const Text(
              'Aún no hay mascotas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azul,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra la primera mascota para tener '
              'su información organizada en PETMEDS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _openPatientForm,
              icon: const Icon(Icons.add),
              label: const Text('Registrar mascota'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: azul,
        foregroundColor: Colors.white,
        title: const Text(
          'Mascotas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPatientForm,
        backgroundColor: verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva mascota'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: verde))
          : patients.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: loadPatients,
              color: verde,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                children: [
                  const Text(
                    'Nuestros compañeros',
                    style: TextStyle(
                      color: azul,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${patients.length} '
                    '${patients.length == 1 ? 'mascota registrada' : 'mascotas registradas'}',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...patients.map(_buildPatientCard),
                ],
              ),
            ),
    );
  }
}
