import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'parameter_service.dart';
import 'pending_dose_service.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await AlarmService._onNotificationResponse(response);
}

class AlarmService {
  // ============================================================
  // INSTANCIA ÚNICA
  // ============================================================

  static final AlarmService instance = AlarmService._init();

  AlarmService._init();

  // ============================================================
  // PLUGIN
  // ============================================================

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ============================================================
  // INICIALIZAR
  // ============================================================

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            'dose_actions',
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                'ADMINISTER',
                'ADMINISTRAR',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                'OMIT',
                'OMITIR',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                'POSTPONE',
                'POSPONER',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      ),
    );

    await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final parameterService = ParameterService();
    final permissionsRequested = await parameterService.getParameter(
      'alarmPermissionsRequested',
    );
    final notificationsEnabled = await parameterService
        .areNotificationsEnabled();
    if (permissionsRequested != '1' && notificationsEnabled) {
      await requestPermissions();
      await parameterService.setParameter('alarmPermissionsRequested', '1');
    }

    // Si PETMEDS fue abierta tocando una notificación,
    // procesar la acción correspondiente.
    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();

    final response = launchDetails?.notificationResponse;

    if (launchDetails?.didNotificationLaunchApp == true &&
        response != null &&
        response.actionId != null &&
        response.actionId!.isNotEmpty) {
      await _onNotificationResponse(response);
    }
  }

  /// Solicita permisos del sistema para notificaciones y alarmas exactas.
  /// Puede llamarse otra vez desde Ajustes si el usuario los concedió allí.
  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final notificationsGranted = await android
          .requestNotificationsPermission();
      final exactAlarmsGranted = await android.requestExactAlarmsPermission();
      return notificationsGranted != false && exactAlarmsGranted != false;
    }

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<bool> hasRequiredPermissions() async {
    if (!await canShowNotifications()) {
      return false;
    }

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final exactAlarmsAllowed = await android.canScheduleExactNotifications();
      return exactAlarmsAllowed == true;
    }

    return true;
  }

  Future<bool> canShowNotifications() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() == true;
    }

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled == true;
    }

    return true;
  }

  // ============================================================
  // RESPUESTA A LAS ACCIONES
  // ============================================================

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    final payload = response.payload;

    // Tocar simplemente la notificación no modifica
    // ninguna dosis.
    if (actionId == null || actionId.isEmpty) {
      return;
    }

    if (payload == null || payload.isEmpty) {
      return;
    }

    final pendingDoseId = int.tryParse(payload);

    if (pendingDoseId == null) {
      return;
    }

    // Cancelar la notificación actual antes de
    // resolver o modificar la dosis.
    await AlarmService.instance.cancelAlarm(response.id);

    final pendingDoseService = PendingDoseService();

    // ==========================================================
    // ADMINISTRAR
    // ==========================================================

    if (actionId == 'ADMINISTER') {
      final resolved = await pendingDoseService.administerDose(pendingDoseId);

      if (resolved == 0) {
        return;
      }

      await _scheduleNextPendingDose(pendingDoseService);
      return;
    }

    // ==========================================================
    // OMITIR
    // ==========================================================

    if (actionId == 'OMIT') {
      final resolved = await pendingDoseService.omitDose(pendingDoseId);

      if (resolved == 0) {
        return;
      }

      await _scheduleNextPendingDose(pendingDoseService);
      return;
    }

    // ==========================================================
    // POSPONER
    // ==========================================================

    if (actionId == 'POSTPONE') {
      final parameterService = ParameterService();

      final postponeMinutes = await parameterService.getPostponeMinutes();

      final updated = await pendingDoseService.postponeDose(
        pendingDoseId,
        postponeMinutes,
      );

      if (updated == 0) {
        return;
      }

      // Obtener nuevamente la misma pending_dose.
      //
      // scheduledDateTime NO cambia.
      // Solamente cambia alarmDateTime.
      final pendingDose = await pendingDoseService.getPendingDoseByIdForAlarm(
        pendingDoseId,
      );

      if (pendingDose == null || pendingDose.id == null) {
        return;
      }

      final now = DateTime.now();

      if (!pendingDose.alarmDateTime.isAfter(now)) {
        return;
      }

      final detail = await pendingDoseService.getPendingDoseDetail(
        pendingDoseId,
      );

      if (detail == null) {
        return;
      }

      final notificationData = buildNotificationData(detail);

      await AlarmService.instance.scheduleAlarm(
        notificationId: pendingDose.id!,
        alarmDateTime: pendingDose.alarmDateTime,
        title: notificationData['title']!,
        body: notificationData['body']!,
        payload: pendingDose.id.toString(),
      );

      return;
    }
  }

  // ============================================================
  // CONSTRUIR INFORMACIÓN DE NOTIFICACIÓN
  // ============================================================

  static Map<String, String> buildNotificationData(
    Map<String, dynamic> detail,
  ) {
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

    String doseText = '';

    if (doseAmount != null &&
        doseAmount.isNotEmpty &&
        doseUnit != null &&
        doseUnit.isNotEmpty) {
      doseText = '$doseAmount $doseUnit';
    } else if (doseAmount != null && doseAmount.isNotEmpty) {
      doseText = doseAmount;
    }

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

    return {'title': title, 'body': bodyLines.join('\n')};
  }

  // ============================================================
  // FORMATEAR FECHA Y HORA
  // ============================================================

  static String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');

    final month = dateTime.month.toString().padLeft(2, '0');

    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  // ============================================================
  // MOSTRAR DOSIS PENDIENTE INMEDIATAMENTE
  // ============================================================

  Future<void> showPendingDoseNotification({
    required int notificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Respetar configuración de notificaciones.
    final enabled = await ParameterService().areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    if (!await canShowNotifications()) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'petmeds_pending_doses',
      'Dosis pendientes PETMEDS',
      channelDescription: 'Notificaciones de dosis pendientes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'ADMINISTER',
          'ADMINISTRAR',
          showsUserInterface: true,
        ),
        AndroidNotificationAction('OMIT', 'OMITIR', showsUserInterface: true),
        AndroidNotificationAction(
          'POSTPONE',
          'POSPONER',
          showsUserInterface: true,
        ),
      ],
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(categoryIdentifier: 'dose_actions'),
    );

    await _notifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  // ============================================================
  // PROGRAMAR ALARMA
  // ============================================================

  Future<void> scheduleAlarm({
    required int notificationId,
    required DateTime alarmDateTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Respetar configuración de notificaciones.
    final enabled = await ParameterService().areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    if (!await hasRequiredPermissions()) {
      return;
    }

    final now = DateTime.now();

    // Nunca programar una fecha pasada.
    if (!alarmDateTime.isAfter(now)) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(alarmDateTime, tz.local);

    final tzNow = tz.TZDateTime.now(tz.local);

    if (!scheduledDate.isAfter(tzNow)) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'petmeds_alarms',
      'Alarmas PETMEDS',
      channelDescription: 'Alarmas para administrar medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'ADMINISTER',
          'ADMINISTRAR',
          showsUserInterface: true,
        ),
        AndroidNotificationAction('OMIT', 'OMITIR', showsUserInterface: true),
        AndroidNotificationAction(
          'POSTPONE',
          'POSPONER',
          showsUserInterface: true,
        ),
      ],
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(categoryIdentifier: 'dose_actions'),
    );

    await _notifications.zonedSchedule(
      id: notificationId,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  // ============================================================
  // CANCELAR ALARMA
  // ============================================================

  Future<void> cancelAlarm(int? notificationId) async {
    if (notificationId == null) {
      return;
    }

    await _notifications.cancel(id: notificationId);
  }

  // ============================================================
  // CANCELAR TODAS LAS ALARMAS
  // ============================================================

  Future<void> cancelAllAlarms() async {
    await _notifications.cancelAll();
  }

  // ============================================================
  // PROGRAMAR LA PRÓXIMA PENDING DOSE
  // ============================================================

  static Future<void> _scheduleNextPendingDose(
    PendingDoseService service,
  ) async {
    final pendingDoses = await service.getPendingDoses();

    if (pendingDoses.isEmpty) {
      return;
    }

    pendingDoses.sort((a, b) => a.alarmDateTime.compareTo(b.alarmDateTime));

    final now = DateTime.now();

    // Buscar la primera PENDING según su
    // hora de alarma.
    for (final dose in pendingDoses) {
      if (dose.id == null) {
        continue;
      }

      final detail = await service.getPendingDoseDetail(dose.id!);

      if (detail == null) {
        continue;
      }

      final notificationData = buildNotificationData(detail);

      // ========================================================
      // DOSIS YA VENCIDA
      // ========================================================

      if (!dose.alarmDateTime.isAfter(now)) {
        await AlarmService.instance.showPendingDoseNotification(
          notificationId: dose.id!,
          title: notificationData['title']!,
          body: notificationData['body']!,
          payload: dose.id.toString(),
        );

        return;
      }

      // ========================================================
      // DOSIS FUTURA
      // ========================================================

      await AlarmService.instance.scheduleAlarm(
        notificationId: dose.id!,
        alarmDateTime: dose.alarmDateTime,
        title: notificationData['title']!,
        body: notificationData['body']!,
        payload: dose.id.toString(),
      );

      return;
    }
  }
}
