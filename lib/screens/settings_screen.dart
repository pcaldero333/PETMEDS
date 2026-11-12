import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/pending_dose_service.dart';
import 'notification_settings_screen.dart';
import 'patients_screen.dart';
import 'medicines_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _azul = Color(0xFF163B52);
  static const Color _verde = Color(0xFF287C68);
  static const Color _fondo = Color(0xFFF3F7F5);
  static const Color _rojo = Color(0xFFC74747);

  bool _isResetting = false;
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  // ============================================================
  // ELIMINAR DATOS DE LA APLICACIÓN
  // ============================================================

  Future<void> _resetApplicationData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _rojo.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_outlined,
              color: _rojo,
              size: 30,
            ),
          ),
          title: const Text(
            'Eliminar datos',
            textAlign: TextAlign.center,
            style: TextStyle(color: _azul, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Esta operación eliminará todos los tratamientos, '
            'dosis pendientes y el historial de dosis.\n\n'
            'También cancelará todas las alarmas de PETMEDS.\n\n'
            'Las mascotas y los medicamentos registrados '
            'NO serán eliminados.\n\n'
            '¿Desea continuar?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _azul,
                side: const BorderSide(color: _azul),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ELIMINAR'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isResetting = true;
    });

    try {
      await PendingDoseService().resetTestDatabase();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de la aplicación eliminados correctamente.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar los datos: $e'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
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
  // COMPONENTES VISUALES
  // ============================================================

  Widget _sectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _azul,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE9)),
        boxShadow: [
          BoxShadow(
            color: _azul.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _verde.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _verde, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _azul,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.shade500,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFE9EEEC)),
          ),
      ],
    );
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _azul,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personaliza PETMEDS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Administra las opciones de tu aplicación.',
                          style: TextStyle(
                            color: Color(0xFFDCE8EC),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // General
            _sectionHeading('General', 'Gestiona las opciones principales'),

            _settingsCard(
              child: Column(
                children: [
                  _settingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificaciones',
                    subtitle: 'Configuración de avisos y alarmas',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsTile(
                    icon: Icons.pets_outlined,
                    title: 'Mascotas',
                    subtitle: 'Administrar mascotas registradas',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientsScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsTile(
                    icon: Icons.medication_outlined,
                    title: 'Medicamentos',
                    subtitle: 'Administrar medicamentos registrados',
                    showDivider: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MedicinesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Datos de la aplicación
            _sectionHeading(
              'Datos de la aplicación',
              'Consulta y administra los registros almacenados',
            ),

            _settingsCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _rojo.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.storage_outlined,
                            color: _rojo,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Restablecer datos',
                            style: TextStyle(
                              color: _azul,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Esta opción elimina los tratamientos y los '
                      'registros de dosis almacenados en PETMEDS.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Se eliminarán:',
                      style: TextStyle(
                        color: _azul,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 9),

                    _deletionItem('Tratamientos'),
                    _deletionItem('Dosis pendientes'),
                    _deletionItem('Historial de dosis'),
                    _deletionItem('Alarmas programadas'),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _verde.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: _verde, size: 19),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Las mascotas y los medicamentos '
                              'registrados se conservarán.',
                              style: TextStyle(
                                color: _azul,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isResetting ? null : _resetApplicationData,
                        style: FilledButton.styleFrom(
                          backgroundColor: _rojo,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _rojo.withValues(
                            alpha: 0.45,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isResetting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text(
                          _isResetting
                              ? 'ELIMINANDO...'
                              : 'ELIMINAR DATOS DE LA APLICACIÓN',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Información
            _sectionHeading('Información', 'Acerca de PETMEDS'),

            _settingsCard(
              child: Column(
                children: [
                  _settingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'PETMEDS',
                    subtitle:
                        'Sistema de gestión y recordatorio de medicamentos '
                        'para mascotas',
                    showDivider: true,
                    onTap: () {
                      _showInformation();
                    },
                  ),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      final subtitle = snapshot.hasData
                          ? 'Versión ${snapshot.data!.version} '
                                '(compilación ${snapshot.data!.buildNumber})'
                          : 'Consultando versión…';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            Icons.code_rounded,
                            color: _verde,
                            size: 25,
                          ),
                        ),
                        title: const Text(
                          'Versión',
                          style: TextStyle(
                            color: _azul,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(subtitle),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  const Icon(Icons.favorite_rounded, color: _verde, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    'PETMEDS · Cuidado y bienestar',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deletionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, color: _rojo, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showInformation() {
    showAboutDialog(
      context: context,
      applicationName: 'PETMEDS',
      applicationVersion: 'Versión de desarrollo',
      applicationIcon: const Icon(Icons.pets_rounded, color: _verde, size: 38),
      applicationLegalese: 'Cuidado y bienestar de tus mascotas.',
    );
  }
}
