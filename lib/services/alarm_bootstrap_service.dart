import 'dart:async';

import 'alarm_service.dart';
import 'pending_dose_service.dart';

class AlarmBootstrapService {
  static final AlarmBootstrapService instance = AlarmBootstrapService._init();

  AlarmBootstrapService._init();

  final AlarmService _alarmService = AlarmService.instance;

  final PendingDoseService _pendingDoseService = PendingDoseService();

  // ------------------------------------------------------------
  // Guarda la última versión de alarma que ya fue mostrada.
  //
  // key   = pendingDose.id
  // value = alarmDateTime
  // ------------------------------------------------------------

  final Map<int, String> _shownAlarmDateTimes = {};

  Timer? _monitorTimer;

  bool _checkingDoses = false;

  // ============================================================
  // INICIALIZAR SISTEMA DE ALARMAS
  // ============================================================

  Future<void> initialize() async {
    await _alarmService.initialize();

    await _checkDueDoses();

    _monitorTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDueDoses();
    });
  }

  // ============================================================
  // COMPROBAR DOSIS
  // ============================================================

  Future<void> _checkDueDoses() async {
    // ----------------------------------------------------------
    // Evitar que dos comprobaciones se ejecuten simultáneamente.
    // ----------------------------------------------------------

    if (_checkingDoses) {
      return;
    }

    _checkingDoses = true;

    try {
      // --------------------------------------------------------
      // Asegurar que exista la próxima PENDING.
      //
      // Esto NO genera MISSED.
      // --------------------------------------------------------

      await _pendingDoseService.createDuePendingDoses();

      // --------------------------------------------------------
      // Obtener TODAS las PENDING.
      // --------------------------------------------------------

      final pendingDoses = await _pendingDoseService.getPendingDoses();

      if (pendingDoses.isEmpty) {
        return;
      }

      pendingDoses.sort((a, b) => a.alarmDateTime.compareTo(b.alarmDateTime));

      final now = DateTime.now();

      // --------------------------------------------------------
      // Procesar las PENDING.
      // --------------------------------------------------------

      for (final dose in pendingDoses) {
        if (dose.id == null) {
          continue;
        }

        final detail = await _pendingDoseService.getPendingDoseDetail(dose.id!);

        if (detail == null) {
          continue;
        }

        final notificationData = _buildNotificationData(detail);

        // ======================================================
        // DOSIS VENCIDA
        // ======================================================

        if (!dose.alarmDateTime.isAfter(now)) {
          final alarmDateTimeKey = dose.alarmDateTime.toIso8601String();

          if (_shownAlarmDateTimes[dose.id!] == alarmDateTimeKey) {
            continue;
          }

          await _alarmService.showPendingDoseNotification(
            notificationId: dose.id!,
            title: notificationData['title']!,
            body: notificationData['body']!,
            payload: dose.id.toString(),
          );

          _shownAlarmDateTimes[dose.id!] = alarmDateTimeKey;

          // ----------------------------------------------------
          // Solamente mostrar la primera dosis vencida.
          //
          // La siguiente se procesará cuando el usuario resuelva
          // esta dosis.
          // ----------------------------------------------------

          continue;
        }

        // ======================================================
        // DOSIS FUTURA
        // ======================================================

        await _alarmService.scheduleAlarm(
          notificationId: dose.id!,
          alarmDateTime: dose.alarmDateTime,
          title: notificationData['title']!,
          body: notificationData['body']!,
          payload: dose.id.toString(),
        );
      }
    } finally {
      _checkingDoses = false;
    }
  }

  // ============================================================
  // CONSTRUIR INFORMACIÓN DE NOTIFICACIÓN
  // ============================================================

  Map<String, String> _buildNotificationData(Map<String, dynamic> detail) {
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

    final scheduledText = _formatDateTime(scheduledDateTime);

    final alarmText = _formatDateTime(alarmDateTime);

    // ----------------------------------------------------------
    // Cantidad
    // ----------------------------------------------------------

    String doseText = '';

    if (doseAmount != null &&
        doseAmount.isNotEmpty &&
        doseUnit != null &&
        doseUnit.isNotEmpty) {
      doseText = '$doseAmount $doseUnit';
    } else if (doseAmount != null && doseAmount.isNotEmpty) {
      doseText = doseAmount;
    }

    // ----------------------------------------------------------
    // Título
    // ----------------------------------------------------------

    final title = '🐾 $patientName · 💊 $medicineName';

    // ----------------------------------------------------------
    // Cuerpo
    // ----------------------------------------------------------

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

    return {'title': title, 'body': bodyLines.join('\n')};
  }

  // ============================================================
  // FORMATEAR FECHA Y HORA
  // ============================================================

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');

    final month = dateTime.month.toString().padLeft(2, '0');

    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  // ============================================================
  // REINICIAR ESTADO DEL MONITOR
  // ============================================================
  //
  // IMPORTANTE:
  //
  // Este método NO toca la base de datos.
  // Solamente elimina el estado temporal que mantiene el monitor.
  //
  // Se utiliza desde resetTestDatabase().
  //
  // ============================================================

  void resetMonitorState() {
    _shownAlarmDateTimes.clear();
    _checkingDoses = false;
  }

  // ============================================================
  // DETENER MONITOR
  // ============================================================

  void dispose() {
    _monitorTimer?.cancel();
    _monitorTimer = null;

    resetMonitorState();
  }
}
