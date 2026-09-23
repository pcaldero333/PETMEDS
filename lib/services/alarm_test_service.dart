import 'package:petmeds/services/alarm_service.dart';

class AlarmTestService {
  static Future<void> createTestAlarm() async {
    final alarmService = AlarmService.instance;

    final now = DateTime.now();
    final alarmTime = now.add(const Duration(minutes: 2));

    print('========================================');
    print('PETMEDS - PRUEBA DE ALARMA');
    print('Hora actual: $now');
    print('Hora programada: $alarmTime');
    print('========================================');

    await alarmService.scheduleAlarm(
      notificationId: 999999,
      alarmDateTime: alarmTime,
      title: 'PETMEDS - PRUEBA',
      body: 'Esta es una prueba directa del sistema de alarmas.',
    );

    print('ALARMA PROGRAMADA CORRECTAMENTE');
  }
}
