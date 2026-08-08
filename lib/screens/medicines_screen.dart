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
  final MedicineService _medicineService = MedicineService();

  List<Medicine> medicines = [];

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  Future<void> loadMedicines() async {
    final data = await _medicineService.getMedicines();

    if (!mounted) return;

    setState(() {
      medicines = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medicamentos"), centerTitle: true),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicineFormScreen()),
          );

          if (resultado == true) {
            await loadMedicines();
          }
        },
      ),

      body: medicines.isEmpty
          ? const Center(
              child: Text(
                "No hay medicamentos registrados",
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: medicines.length,

              itemBuilder: (context, index) {
                final medicine = medicines[index];

                return Card(
                  margin: const EdgeInsets.all(10),

                  child: ListTile(
                    onTap: () async {
                      final resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MedicineFormScreen(medicine: medicine),
                        ),
                      );

                      if (resultado == true) {
                        await loadMedicines();
                      }
                    },

                    leading: const CircleAvatar(child: Icon(Icons.medication)),

                    title: Text(
                      medicine.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text(
                      "${medicine.presentation} - "
                      "${medicine.concentration}",
                    ),

                    trailing: const Icon(Icons.edit, size: 20),
                  ),
                );
              },
            ),
    );
  }
}
