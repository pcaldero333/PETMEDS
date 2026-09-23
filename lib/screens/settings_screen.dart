import 'package:flutter/material.dart';

import '../services/pending_dose_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isResetting = false;

  // ============================================================
  // REINICIAR BASE DE DATOS DE PRUEBA
  // ============================================================

  Future<void> _resetTestDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reiniciar datos de prueba'),
          content: const Text(
            'Esta operación eliminará todos los tratamientos, '
            'dosis pendientes y el historial de dosis.\n\n'
            'También cancelará todas las alarmas de PETMEDS.\n\n'
            'Las mascotas y los medicamentos registrados NO serán eliminados.\n\n'
            '¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('REINICIAR'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isResetting = true;
    });

    try {
      await PendingDoseService().resetTestDatabase();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de prueba reiniciados correctamente.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reiniciar los datos: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ====================================================
            // SECCIÓN GENERAL
            // ====================================================
            const Text(
              'General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notificaciones'),
                    subtitle: const Text('Configuración de avisos y alarmas'),
                    onTap: () {
                      // Reservado para configuración futura.
                    },
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.pets_outlined),
                    title: const Text('Mascotas'),
                    subtitle: const Text('Administrar mascotas registradas'),
                    onTap: () {
                      // Reservado para configuración futura.
                    },
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.medication_outlined),
                    title: const Text('Medicamentos'),
                    subtitle: const Text(
                      'Administrar medicamentos registrados',
                    ),
                    onTap: () {
                      // Reservado para configuración futura.
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ====================================================
            // SECCIÓN DE PRUEBAS
            // ====================================================
            const Text(
              'Pruebas y desarrollo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science_outlined, size: 26),
                        SizedBox(width: 10),
                        Text(
                          'Datos de prueba',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Utilice esta opción para comenzar nuevamente '
                      'las pruebas del sistema de tratamientos y alarmas.',
                      style: TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Se eliminarán:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      '• Tratamientos\n'
                      '• Dosis pendientes\n'
                      '• Historial de dosis\n'
                      '• Alarmas programadas',
                      style: TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'No se eliminarán las mascotas ni los medicamentos.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isResetting ? null : _resetTestDatabase,
                        icon: _isResetting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.restart_alt),
                        label: Text(
                          _isResetting
                              ? 'REINICIANDO...'
                              : 'REINICIAR DATOS DE PRUEBA',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ====================================================
            // INFORMACIÓN
            // ====================================================
            const Text(
              'Información',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('PETMEDS'),
                    subtitle: Text(
                      'Sistema de gestión y recordatorio '
                      'de medicamentos para mascotas',
                    ),
                  ),

                  const Divider(height: 1),

                  const ListTile(
                    leading: Icon(Icons.code_outlined),
                    title: Text('Versión'),
                    subtitle: Text('Versión de desarrollo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
