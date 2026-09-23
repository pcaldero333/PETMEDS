import 'package:flutter/material.dart';

import '../services/alarm_service.dart';
import '../services/pending_dose_service.dart';

import 'patients_screen.dart';
import 'medicines_screen.dart';
import 'treatments_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ============================================================
  // VER DOSIS PENDIENTES
  // ============================================================

  Future<void> _showPendingDose(BuildContext context) async {
    final pendingDoseService = PendingDoseService();

    // ----------------------------------------------------------
    // OBTENER DOSIS PENDIENTES
    // ----------------------------------------------------------

    final pendingDoses = await pendingDoseService.getDuePendingDoses();

    if (!context.mounted) return;

    // ----------------------------------------------------------
    // NO HAY DOSIS PENDIENTES
    // ----------------------------------------------------------

    if (pendingDoses.isEmpty) {
      final nextDose = await pendingDoseService.getNextPendingDose();

      if (!context.mounted) return;

      if (nextDose == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay dosis pendientes ni próximas dosis programadas.',
            ),
          ),
        );

        return;
      }

      String formatDateTime(DateTime dateTime) {
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final year = dateTime.year.toString();
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');

        return '$day/$month/$year $hour:$minute';
      }

      final nextText = formatDateTime(nextDose.scheduledDateTime);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay dosis pendientes.\n'
            'Próxima dosis: $nextText',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // ORDENAR POR FECHA/HORA DE ALARMA
    // ----------------------------------------------------------

    pendingDoses.sort((a, b) => a.alarmDateTime.compareTo(b.alarmDateTime));

    final pendingDose = pendingDoses.first;

    // ----------------------------------------------------------
    // VALIDAR ID
    // ----------------------------------------------------------

    if (pendingDose.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La dosis pendiente no tiene un ID válido.'),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // OBTENER DETALLE DE LA DOSIS
    // ----------------------------------------------------------

    final detail = await pendingDoseService.getPendingDoseDetail(
      pendingDose.id!,
    );

    if (detail == null) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo obtener la información completa de la dosis.',
          ),
        ),
      );

      return;
    }

    final patientName = detail['patientName']?.toString() ?? 'Paciente';

    final medicineName = detail['medicineName']?.toString() ?? 'Medicamento';

    final doseAmount = detail['doseAmount']?.toString();

    final doseUnit = detail['doseUnit']?.toString();

    final doseNumber = detail['doseNumber']?.toString() ?? '1';

    final totalDoses = detail['totalDoses']?.toString() ?? '1';

    final scheduledDateTime = DateTime.parse(
      detail['scheduledDateTime'].toString(),
    );

    final alarmDateTime = DateTime.parse(detail['alarmDateTime'].toString());

    String doseText = '';

    if (doseAmount != null &&
        doseAmount.isNotEmpty &&
        doseUnit != null &&
        doseUnit.isNotEmpty) {
      doseText = '$doseAmount $doseUnit';
    } else if (doseAmount != null && doseAmount.isNotEmpty) {
      doseText = doseAmount;
    }

    String formatDateTime(DateTime dateTime) {
      final day = dateTime.day.toString().padLeft(2, '0');

      final month = dateTime.month.toString().padLeft(2, '0');

      final year = dateTime.year.toString();

      final hour = dateTime.hour.toString().padLeft(2, '0');

      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    }

    final scheduledText = formatDateTime(scheduledDateTime);

    final alarmText = formatDateTime(alarmDateTime);

    final title = '🐾 $patientName · 💊 $medicineName';

    final bodyLines = <String>['Dosis $doseNumber de $totalDoses'];

    if (doseText.isNotEmpty) {
      bodyLines.add('Cantidad: $doseText');
    }

    bodyLines.add('Programada: $scheduledText');

    if (alarmDateTime != scheduledDateTime) {
      bodyLines.add('Nueva notificación: $alarmText');
    } else {
      bodyLines.add('Notificación: $alarmText');
    }

    // ----------------------------------------------------------
    // MOSTRAR NOTIFICACIÓN PERSISTENTE
    // ----------------------------------------------------------

    await AlarmService.instance.showPendingDoseNotification(
      notificationId: pendingDose.id!,
      title: title,
      body: bodyLines.join('\n'),
      payload: pendingDose.id.toString(),
    );

    if (!context.mounted) return;

    // ----------------------------------------------------------
    // CONFIRMACIÓN
    // ----------------------------------------------------------

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La dosis pendiente se mostró en las notificaciones.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    final screenWidth = MediaQuery.of(context).size.width;

    // Tamaño adaptable del logo.
    final double logoSize = screenHeight < 500
        ? screenHeight * 0.35
        : screenWidth > 600
        ? 300
        : 360;

    return Scaffold(
      // ==========================================================
      // APP BAR
      // ==========================================================
      appBar: AppBar(
        centerTitle: true,
        title: const Text("PETMEDS"),

        // --------------------------------------------------------
        // BOTÓN CONFIGURACIÓN
        // --------------------------------------------------------
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  const SizedBox(height: 10),

                  // ==================================================
                  // LOGO
                  // ==================================================
                  Center(
                    child: Image.asset(
                      'assets/images/isologo_petmeds.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // NOMBRE
                  // ==================================================
                  const Center(
                    child: Text(
                      "PETMEDS",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ==================================================
                  // SUBTÍTULO
                  // ==================================================
                  const Center(
                    child: Text(
                      "Medication Reminder",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // ==================================================
                  // VER DOSIS PENDIENTES
                  // ==================================================
                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showPendingDose(context);
                      },
                      icon: const Icon(Icons.notifications_active),
                      label: const Text(
                        "VER DOSIS PENDIENTES",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // MASCOTAS
                  // ==================================================
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PatientsScreen(),
                          ),
                        );
                      },
                      child: const Text("Mascotas"),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // MEDICAMENTOS
                  // ==================================================
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MedicinesScreen(),
                          ),
                        );
                      },
                      child: const Text("Medicines"),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // TRATAMIENTOS
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TreatmentsScreen(),
                          ),
                        );
                      },
                      child: const Text("Treatments"),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
