import 'package:flutter/material.dart';

import '../services/alarm_service.dart';
import '../services/pending_dose_service.dart';

import 'patients_screen.dart';
import 'medicines_screen.dart';
import 'treatments_screen.dart';
import 'settings_screen.dart';
import 'treatment_history_screen.dart';

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
    const azul = Color(0xFF163B52);
    const verde = Color(0xFF287C68);
    const fondo = Color(0xFFF3F7F5);

    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth > 600 ? 170.0 : 125.0;
    final columns = screenWidth > 600 ? 4 : 2;

    Widget actionCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: verde.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: verde, size: 27),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: azul,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: azul,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'PETMEDS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // IDENTIDAD VISUAL
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/isologo_petmeds.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cuidar también es recordar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: azul,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Control de medicamentos y tratamientos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DOSIS PENDIENTES
                  const Text(
                    'Seguimiento de medicamentos',
                    style: TextStyle(
                      color: azul,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Card(
                    color: verde,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showPendingDose(context),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              color: Colors.white,
                              size: 38,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ver dosis pendientes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Consultar las dosis que requieren atención',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Administración',
                    style: TextStyle(
                      color: azul,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ACCESOS PRINCIPALES
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: screenWidth > 600 ? 1.35 : 1.15,
                    children: [
                      actionCard(
                        title: 'Mascotas',
                        subtitle: 'Fichas y datos',
                        icon: Icons.pets_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PatientsScreen(),
                            ),
                          );
                        },
                      ),
                      actionCard(
                        title: 'Medicamentos',
                        subtitle: 'Catálogo',
                        icon: Icons.medication_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MedicinesScreen(),
                            ),
                          );
                        },
                      ),
                      actionCard(
                        title: 'Tratamientos',
                        subtitle: 'Pautas y horarios',
                        icon: Icons.calendar_month_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TreatmentsScreen(),
                            ),
                          );
                        },
                      ),
                      actionCard(
                        title: 'Historial',
                        subtitle: 'Registro de dosis',
                        icon: Icons.history_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TreatmentHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'PETMEDS · Cuidado y bienestar',
                      style: TextStyle(
                        color: Colors.blueGrey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
