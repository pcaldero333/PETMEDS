import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import 'medicine_form_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  static const Color azul = Color(0xFF163B52);
  static const Color verde = Color(0xFF287C68);
  static const Color fondo = Color(0xFFF3F7F5);

  final MedicineService _medicineService = MedicineService();

  List<Medicine> medicines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  Future<void> loadMedicines() async {
    try {
      final data = await _medicineService.getMedicines();

      if (!mounted) return;

      setState(() {
        medicines = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible cargar los medicamentos.'),
        ),
      );
    }
  }

  Future<void> _openMedicineForm({Medicine? medicine}) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MedicineFormScreen(medicine: medicine)),
    );

    if (resultado == true && mounted) {
      await loadMedicines();
    }
  }

  Widget _buildMedicineCard(Medicine medicine) {
    final presentation = medicine.presentation.trim();
    final concentration = medicine.concentration.trim();

    final details = [
      if (presentation.isNotEmpty) presentation,
      if (concentration.isNotEmpty) concentration,
    ].join(' · ');

    return Card(
      color: Colors.white,
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _openMedicineForm(medicine: medicine),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F0E9),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: verde,
                  size: 32,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: azul,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        details,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_outlined, color: azul, size: 20),
              ),
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
              child: const Icon(
                Icons.medication_outlined,
                color: verde,
                size: 52,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Aún no hay medicamentos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azul,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra los medicamentos para mantener '
              'el catálogo organizado en PETMEDS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _openMedicineForm(),
              icon: const Icon(Icons.add),
              label: const Text('Registrar medicamento'),
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
        centerTitle: true,
        title: const Text(
          'Medicamentos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMedicineForm(),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo medicamento'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: verde))
          : medicines.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: loadMedicines,
              color: verde,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                children: [
                  const Text(
                    'Catálogo de medicamentos',
                    style: TextStyle(
                      color: azul,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${medicines.length} '
                    '${medicines.length == 1 ? 'medicamento registrado' : 'medicamentos registrados'}',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...medicines.map(_buildMedicineCard),
                ],
              ),
            ),
    );
  }
}
