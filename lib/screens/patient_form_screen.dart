import 'dart:io';

import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../services/patient_service.dart';
import '../services/image_service.dart';

class PatientFormScreen extends StatefulWidget {
  final Patient? patient;

  const PatientFormScreen({super.key, this.patient});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController especieController = TextEditingController();
  final TextEditingController razaController = TextEditingController();
  final TextEditingController propietarioController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController pesoController = TextEditingController();
  final TextEditingController notasController = TextEditingController();

  final PatientService _patientService = PatientService();
  final ImageService _imageService = ImageService();

  String? photoPath;

  String? sexoSeleccionado;

  @override
  void initState() {
    super.initState();

    if (widget.patient != null) {
      nombreController.text = widget.patient!.name;
      especieController.text = widget.patient!.species;
      razaController.text = widget.patient!.breed;
      propietarioController.text = widget.patient!.ownerName;
      telefonoController.text = widget.patient!.ownerPhone;

      sexoSeleccionado = widget.patient!.sex;
      pesoController.text = widget.patient!.weight?.toString() ?? "";
      notasController.text = widget.patient!.notes ?? "";

      photoPath = widget.patient?.photoPath;
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    especieController.dispose();
    razaController.dispose();
    propietarioController.dispose();
    telefonoController.dispose();
    pesoController.dispose();
    notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.patient == null ? "Nueva Mascota" : "Editar Mascota",
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "DATOS DE LA MASCOTA",

                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final path = await _imageService.pickAndSaveImage();

                    if (path != null) {
                      setState(() {
                        photoPath = path;
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: photoPath != null
                        ? FileImage(File(photoPath!))
                        : null,
                    child: photoPath == null
                        ? const Icon(Icons.add_a_photo, size: 40)
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const SizedBox(height: 16),

              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Ingrese el nombre de la mascota";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: especieController,
                decoration: const InputDecoration(labelText: "Especie"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: razaController,
                decoration: const InputDecoration(labelText: "Raza"),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: sexoSeleccionado,
                decoration: const InputDecoration(
                  labelText: "Sexo",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "Macho", child: Text("Macho")),
                  DropdownMenuItem(value: "Hembra", child: Text("Hembra")),
                ],
                onChanged: (value) {
                  setState(() {
                    sexoSeleccionado = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: pesoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: "Peso (Kg)"),
              ),

              const SizedBox(height: 30),

              const Text(
                "DATOS DEL PROPIETARIO",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: propietarioController,
                decoration: const InputDecoration(labelText: "Propietario"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: telefonoController,
                decoration: const InputDecoration(labelText: "Teléfono"),
              ),

              const SizedBox(height: 30),

              const Text(
                "OBSERVACIONES",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: notasController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Notas",
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    final patient = Patient(
                      id: widget.patient?.id,
                      name: nombreController.text.trim(),
                      species: especieController.text.trim(),
                      breed: razaController.text.trim(),
                      sex: sexoSeleccionado,
                      weight: pesoController.text.trim().isEmpty
                          ? null
                          : double.tryParse(pesoController.text.trim()),
                      ownerName: propietarioController.text.trim(),
                      ownerPhone: telefonoController.text.trim(),
                      notes: notasController.text.trim().isEmpty
                          ? null
                          : notasController.text.trim(),
                      photoPath: photoPath,
                    );

                    if (widget.patient == null) {
                      await _patientService.insertPatient(patient);
                    } else {
                      await _patientService.updatePatient(patient);
                    }

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.patient == null
                              ? "Mascota guardada correctamente"
                              : "Mascota actualizada correctamente",
                        ),
                      ),
                    );

                    Navigator.pop(context, true);
                  },
                  child: Text(
                    widget.patient == null ? "Guardar" : "Actualizar",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
