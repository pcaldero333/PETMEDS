import 'dart:async';

import 'alarm_service.dart';
import 'pending_dose_service.dart';
import 'parameter_service.dart';

class AlarmBootstrapService {
  static final AlarmBootstrapService instance = AlarmBootstrapService._init();

  AlarmBootstrapService._init();

  final AlarmService _alarmService = AlarmService.instance;

  final PendingDoseService _pendingDoseService = PendingDoseService();

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
  // ACTUALIZAR INMEDIATAMENTE
  // ============================================================

  Future<void> refresh() async {
    await _checkDueDoses();
  }

  // ============================================================
  // COMPROBAR DOSIS
  // ============================================================

  Future<void> _checkDueDoses() async {
    // Evitar comprobaciones simultÃ¡neas.
    if (_checkingDoses) {
      return;
    }

    _checkingDoses = true;

    try {
      // ========================================================
      // ASEGURAR QUE EXISTAN LAS DOSIS PENDIENTES
      // ========================================================

      await _pendingDoseService.createDuePendingDoses();

      final pendingDoses = await _pendingDoseService.getPendingDoses();

      if (pendingDoses.isEmpty) {
        return;
      }

      // ========================================================
      // COMPROBAR CONFIGURACIÃ“N DE NOTIFICACIONES
      // ========================================================

      final notificationsEnabled = await ParameterService()
          .areNotificationsEnabled();

      if (!notificationsEnabled) {
        // Las dosis siguen existiendo y el motor
        // de tratamientos continÃºa funcionando.
        //
        // Simplemente eliminamos las alarmas Android
        // que pudieran haber quedado programadas.
        await _alarmService.cancelAllAlarms();

        return;
      }

      final canScheduleExactAlarms = await _alarmService
          .hasRequiredPermissions();

      // ========================================================
      // ORDENAR POR HORA DE ALARMA
      // ========================================================

      pendingDoses.sort((a, b) => a.alarmDateTime.compareTo(b.alarmDateTime));

      final now = DateTime.now();

      // ========================================================
      // MOSTRAR UNA DOSIS VENCIDA Y PROGRAMAR LAS FUTURAS
      // ========================================================
      //
      // Solamente se muestra UNA dosis vencida por comprobaciÃ³n.
      //
      // Las demÃ¡s quedan bajo control de
      // PendingDoseService.
      //

      var shownOverdueDose = false;

      for (final dose in pendingDoses) {
        if (dose.id == null) {
          continue;
        }

        if (!dose.alarmDateTime.isAfter(now)) {
          if (shownOverdueDose) {
            continue;
          }

          final detail = await _pendingDoseService.getPendingDoseDetail(
            dose.id!,
          );

          if (detail == null) {
            continue;
          }

          final notificationData = AlarmService.buildNotificationData(detail);

          final alarmDateTimeKey = dose.alarmDateTime.toIso8601String();

          if (_shownAlarmDateTimes[dose.id!] != alarmDateTimeKey) {
            await _alarmService.showPendingDoseNotification(
              notificationId: dose.id!,
              title: notificationData['title']!,
              body: notificationData['body']!,
              payload: dose.id.toString(),
            );

            _shownAlarmDateTimes[dose.id!] = alarmDateTimeKey;
          }

          shownOverdueDose = true;

          // No procesar otras dosis vencidas
          // en esta comprobaciÃ³n.
          break;
        }
      }

      // ========================================================
      // PROGRAMAR DOSIS FUTURAS
      // ========================================================

      for (final dose in pendingDoses) {
        if (dose.id == null) {
          continue;
        }

        if (!dose.alarmDateTime.isAfter(now)) {
          continue;
        }

        if (!canScheduleExactAlarms) {
          continue;
        }

        final detail = await _pendingDoseService.getPendingDoseDetail(dose.id!);

        if (detail == null) {
          continue;
        }

        final notificationData = AlarmService.buildNotificationData(detail);

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
  // REINICIAR ESTADO DEL MONITOR
  // ============================================================

  // Este mÃ©todo NO toca la base de datos.
  //
  // Solamente elimina el estado temporal que mantiene
  // el monitor.
  //
  // Se utiliza desde resetTestDatabase()
  // y desde la configuraciÃ³n de notificaciones.

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
