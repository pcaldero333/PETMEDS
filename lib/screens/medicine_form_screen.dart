import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';

class MedicineFormScreen extends StatefulWidget {
  final Medicine? medicine;

  const MedicineFormScreen({super.key, this.medicine});

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController presentacionController = TextEditingController();
  final TextEditingController concentracionController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  final MedicineService _medicineService = MedicineService();

  @override
  void initState() {
    super.initState();

    if (widget.medicine != null) {
      nombreController.text = widget.medicine!.name;
      presentacionController.text = widget.medicine!.presentation;
      concentracionController.text = widget.medicine!.concentration;
      observacionesController.text = widget.medicine!.observations;
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    presentacionController.dispose();
    concentracionController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

  Future<void> eliminarMedicamento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Eliminar medicamento"),

          content: Text(
            "¿Está seguro de eliminar a ${widget.medicine!.name}?\n\n"
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

    if (!mounted) return;

    if (confirmar == true) {
      await _medicineService.deleteMedicine(widget.medicine!.id!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${widget.medicine!.name} fue eliminado.")),
      );

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editando = widget.medicine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? "Editar Medicamento" : "Nuevo Medicamento"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: ListView(
            children: [
              const Text(
                "DATOS DEL MEDICAMENTO",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: nombreController,

                decoration: const InputDecoration(
                  labelText: "Nombre",
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Ingrese el nombre del medicamento";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: presentacionController,

                decoration: const InputDecoration(
                  labelText: "Presentación",
                  hintText: "Ej: Tabletas, cápsulas, gotas, jarabe",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: concentracionController,

                decoration: const InputDecoration(
                  labelText: "Concentración",
                  hintText: "Ej: 50 mg, 100 mg/ml",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "OBSERVACIONES",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: observacionesController,

                maxLines: 4,

                decoration: const InputDecoration(
                  labelText: "Observaciones",
                  hintText: "Información adicional del medicamento",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              // BOTÓN GUARDAR / ACTUALIZAR
              SizedBox(
                height: 55,

                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    final medicine = Medicine(
                      id: widget.medicine?.id,
                      name: nombreController.text.trim(),
                      presentation: presentacionController.text.trim(),
                      concentration: concentracionController.text.trim(),
                      observations: observacionesController.text.trim(),
                    );

                    if (widget.medicine == null) {
                      await _medicineService.insertMedicine(medicine);
                    } else {
                      await _medicineService.updateMedicine(medicine);
                    }

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.medicine == null
                              ? "Medicamento guardado correctamente"
                              : "Medicamento actualizado correctamente",
                        ),
                      ),
                    );

                    Navigator.pop(context, true);
                  },

                  child: Text(
                    editando ? "Actualizar" : "Guardar",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),

              // BOTÓN ELIMINAR
              if (editando) ...[
                const SizedBox(height: 15),

                SizedBox(
                  height: 55,

                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),

                    icon: const Icon(Icons.delete),

                    label: const Text(
                      "Eliminar medicamento",
                      style: TextStyle(fontSize: 18),
                    ),

                    onPressed: eliminarMedicamento,
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
