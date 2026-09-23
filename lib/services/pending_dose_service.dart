import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/pending_dose.dart';
import '../models/treatment.dart';
import 'alarm_service.dart';
import 'alarm_bootstrap_service.dart';

class PendingDoseService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ============================================================
  // OBTENER TODAS LAS DOSIS PENDIENTES
  // ============================================================

  Future<List<PendingDose>> getPendingDoses() async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'pending_doses',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'scheduledDateTime ASC',
    );

    return result.map((map) => PendingDose.fromMap(map)).toList();
  }

  // ============================================================
  // OBTENER DOSIS CUYA ALARMA YA DEBE MOSTRARSE
  // ============================================================

  Future<List<PendingDose>> getDuePendingDoses() async {
    final db = await _dbHelper.database;

    final now = DateTime.now().toIso8601String();

    final result = await db.query(
      'pending_doses',
      where: 'status = ? AND alarmDateTime <= ?',
      whereArgs: ['PENDING', now],
      orderBy: 'alarmDateTime ASC',
    );

    return result.map((map) => PendingDose.fromMap(map)).toList();
  }

  Future<PendingDose?> getNextPendingDose() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final rows = await db.query(
      'pending_doses',
      where: 'status = ? AND alarmDateTime > ?',
      whereArgs: ['PENDING', now.toIso8601String()],
      orderBy: 'alarmDateTime ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return PendingDose.fromMap(rows.first);
  }
  // ============================================================
  // CREAR DOSIS PENDIENTES
  // ============================================================
  //
  // REGLA FUNDAMENTAL:
  //
  // El paso del tiempo NUNCA genera MISSED.
  //
  // MISSED solamente se genera cuando el usuario decide
  // administrar u omitir una dosis posterior y existen ticks
  // anteriores que todavía no habían sido resueltos.
  //
  // IMPORTANTE:
  //
  // Si han quedado muchas dosis atrasadas, NO se crean todas
  // como PENDING una detrás de otra.
  //
  // Se crea solamente la última dosis programada que ya debería
  // haber ocurrido.
  //
  // Cuando el usuario la resuelve, _resolveDose() detectará
  // automáticamente los ticks anteriores y los registrará
  // como MISSED.
  //
  // ============================================================

  Future<List<PendingDose>> createDuePendingDoses() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final treatmentRows = await db.query(
      'treatments',
      where: 'active = ?',
      whereArgs: [1],
    );

    final createdDoses = <PendingDose>[];

    for (final row in treatmentRows) {
      final treatment = Treatment.fromMap(row);

      if (treatment.id == null) continue;
      if (treatment.frequencyHours <= 0) continue;

      // ------------------------------------------------------------
      // Si ya existe una dosis PENDING para este tratamiento,
      // no creamos otra.
      // ------------------------------------------------------------
      final existingPending = await db.query(
        'pending_doses',
        where: 'treatmentId = ? AND status = ?',
        whereArgs: [treatment.id, 'PENDING'],
        limit: 1,
      );

      if (existingPending.isNotEmpty) continue;

      // ------------------------------------------------------------
      // Buscar la última dosis que ya tuvo una resolución:
      // ADMINISTERED u OMITTED.
      //
      // IMPORTANTE:
      // Para calcular el siguiente tick utilizamos
      // scheduledDateTime, NO administeredDateTime.
      // ------------------------------------------------------------
      final lastActionResult = await db.query(
        'dose_history',
        where: 'treatmentId = ? AND status IN (?, ?)',
        whereArgs: [treatment.id, 'ADMINISTERED', 'OMITTED'],
        orderBy: 'id DESC',
        limit: 1,
      );

      DateTime nextScheduledDateTime;

      if (lastActionResult.isNotEmpty) {
        final scheduledText = lastActionResult.first['scheduledDateTime']
            ?.toString();

        if (scheduledText == null || scheduledText.isEmpty) {
          nextScheduledDateTime = treatment.startDate;
        } else {
          final lastScheduledDateTime = DateTime.parse(scheduledText);

          nextScheduledDateTime = lastScheduledDateTime.add(
            Duration(hours: treatment.frequencyHours),
          );
        }
      } else {
        // No existe ninguna dosis resuelta todavía.
        // La primera dosis corresponde al inicio del tratamiento.
        nextScheduledDateTime = treatment.startDate;
      }

      // Nunca permitir una dosis anterior al inicio del tratamiento.
      if (nextScheduledDateTime.isBefore(treatment.startDate)) {
        nextScheduledDateTime = treatment.startDate;
      }

      // ------------------------------------------------------------
      // AVANZAR HASTA EL ÚLTIMO TICK QUE YA HAYA LLEGADO.
      //
      // Ejemplo:
      //
      // última resuelta = 15:40
      // frecuencia      = 1 hora
      // ahora            = 18:10
      //
      // 16:40 -> vencida
      // 17:40 -> vencida
      // 18:40 -> futura
      //
      // Por lo tanto el PENDING será solamente 17:40.
      // ------------------------------------------------------------
      while (true) {
        final followingTick = nextScheduledDateTime.add(
          Duration(hours: treatment.frequencyHours),
        );

        if (followingTick.isAfter(treatment.endDate)) {
          break;
        }

        if (followingTick.isAfter(now)) {
          break;
        }

        nextScheduledDateTime = followingTick;
      }

      // ------------------------------------------------------------
      // Si el último tick calculado está después del final,
      // el tratamiento ya terminó.
      // ------------------------------------------------------------
      if (nextScheduledDateTime.isAfter(treatment.endDate)) {
        await _finishTreatment(db, treatment.id!);
        continue;
      }

      // ------------------------------------------------------------
      // Verificar que este tick todavía no esté registrado
      // en dose_history.
      // ------------------------------------------------------------
      final alreadyProcessed = await db.query(
        'dose_history',
        where: 'treatmentId = ? AND scheduledDateTime = ?',
        whereArgs: [treatment.id, nextScheduledDateTime.toIso8601String()],
        limit: 1,
      );

      if (alreadyProcessed.isNotEmpty) {
        // Este tick ya fue resuelto. Avanzamos al siguiente.
        nextScheduledDateTime = nextScheduledDateTime.add(
          Duration(hours: treatment.frequencyHours),
        );

        if (nextScheduledDateTime.isAfter(treatment.endDate)) {
          await _finishTreatment(db, treatment.id!);
          continue;
        }
      }

      // ------------------------------------------------------------
      // Crear UNA SOLA dosis PENDING.
      //
      // Si ya llegó la hora, alarmDateTime = now.
      // Si todavía es futura, alarmDateTime = scheduledDateTime.
      // ------------------------------------------------------------
      final alarmDateTime = nextScheduledDateTime.isAfter(now)
          ? nextScheduledDateTime
          : now;

      final id = await db.insert('pending_doses', {
        'treatmentId': treatment.id,
        'patientId': treatment.patientId,
        'scheduledDateTime': nextScheduledDateTime.toIso8601String(),
        'alarmDateTime': alarmDateTime.toIso8601String(),
        'status': 'PENDING',
      });

      createdDoses.add(
        PendingDose(
          id: id,
          treatmentId: treatment.id!,
          patientId: treatment.patientId,
          scheduledDateTime: nextScheduledDateTime,
          alarmDateTime: alarmDateTime,
          status: 'PENDING',
        ),
      );
    }

    return createdDoses;
  }

  // ============================================================
  // OBTENER DOSIS PENDIENTE DE UN TRATAMIENTO
  // ============================================================

  Future<PendingDose?> getPendingDoseByTreatment(int treatmentId) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'pending_doses',
      where: 'treatmentId = ? AND status = ?',
      whereArgs: [treatmentId, 'PENDING'],
      orderBy: 'scheduledDateTime ASC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return PendingDose.fromMap(result.first);
  }

  // ============================================================
  // OBTENER DOSIS PENDIENTE POR ID PARA ALARMA
  // ============================================================

  Future<PendingDose?> getPendingDoseByIdForAlarm(int pendingDoseId) async {
    return _getPendingDoseById(pendingDoseId);
  }

  // ============================================================
  // CREAR DOSIS PENDIENTE MANUALMENTE
  // ============================================================

  Future<int> createPendingDose({
    required int treatmentId,
    required int patientId,
    required DateTime scheduledDateTime,
  }) async {
    final db = await _dbHelper.database;

    final treatment = await _getTreatment(treatmentId);

    if (treatment == null) {
      return 0;
    }

    if (scheduledDateTime.isAfter(treatment.endDate)) {
      await _finishTreatment(db, treatmentId);
      return 0;
    }

    final existing = await db.query(
      'pending_doses',
      where: 'treatmentId = ? AND status = ?',
      whereArgs: [treatmentId, 'PENDING'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    final now = DateTime.now();

    final alarmDateTime = scheduledDateTime.isAfter(now)
        ? scheduledDateTime
        : now;

    final pendingDose = PendingDose(
      treatmentId: treatmentId,
      patientId: patientId,
      scheduledDateTime: scheduledDateTime,
      alarmDateTime: alarmDateTime,
      status: 'PENDING',
    );

    return db.insert('pending_doses', pendingDose.toMap());
  }

  // ============================================================
  // POSPONER DOSIS
  // ============================================================
  //
  // NO modifica scheduledDateTime.
  // NO crea historial.
  // NO genera MISSED.
  //
  // ============================================================

  Future<int> postponeDose(int pendingDoseId, int postponeMinutes) async {
    final db = await _dbHelper.database;

    final pendingDose = await _getPendingDoseById(pendingDoseId);

    if (pendingDose == null) {
      return 0;
    }

    final newAlarmDateTime = pendingDose.alarmDateTime.add(
      Duration(minutes: postponeMinutes),
    );

    return db.update(
      'pending_doses',
      {
        'alarmDateTime': newAlarmDateTime.toIso8601String(),
        'status': 'PENDING',
      },
      where: 'id = ? AND status = ?',
      whereArgs: [pendingDoseId, 'PENDING'],
    );
  }

  // ============================================================
  // ADMINISTRAR DOSIS
  // ============================================================

  Future<int> administerDose(int pendingDoseId) async {
    return _resolveDose(pendingDoseId, 'ADMINISTERED');
  }

  // ============================================================
  // OMITIR DOSIS
  // ============================================================

  Future<int> omitDose(int pendingDoseId) async {
    return _resolveDose(pendingDoseId, 'OMITTED');
  }

  // ============================================================
  // RESOLVER DOSIS
  // ============================================================
  //
  // MISSED solamente puede ser generado aquí.
  //
  // ============================================================

  Future<int> _resolveDose(int pendingDoseId, String userStatus) async {
    final db = await _dbHelper.database;

    return db.transaction<int>((txn) async {
      // ========================================================
      // 1. OBTENER PENDING ACTUAL
      // ========================================================

      final pendingResult = await txn.query(
        'pending_doses',
        where: 'id = ? AND status = ?',
        whereArgs: [pendingDoseId, 'PENDING'],
        limit: 1,
      );

      if (pendingResult.isEmpty) {
        return 0;
      }

      final pendingDose = PendingDose.fromMap(pendingResult.first);

      // ========================================================
      // 2. OBTENER TRATAMIENTO
      // ========================================================

      final treatmentResult = await txn.query(
        'treatments',
        where: 'id = ?',
        whereArgs: [pendingDose.treatmentId],
        limit: 1,
      );

      if (treatmentResult.isEmpty) {
        return 0;
      }

      final treatment = Treatment.fromMap(treatmentResult.first);

      if (treatment.id == null) {
        return 0;
      }

      // ========================================================
      // 3. VALIDAR FRECUENCIA
      // ========================================================

      if (treatment.frequencyHours <= 0) {
        return 0;
      }

      // ========================================================
      // 4. VALIDAR END DATE
      // ========================================================

      if (pendingDose.scheduledDateTime.isAfter(treatment.endDate)) {
        await txn.delete(
          'pending_doses',
          where: 'id = ?',
          whereArgs: [pendingDoseId],
        );

        await _finishTreatment(txn, treatment.id!);

        return 0;
      }

      final now = DateTime.now();

      // ========================================================
      // 4A. PROTECCIÓN CONTRA DOSIS FUTURAS
      //
      // Nunca permitir administrar u omitir una dosis cuya
      // alarma todavía no ha llegado.
      //
      // Esto protege incluso si _resolveDose() es llamado
      // directamente desde otro lugar de la aplicación.
      // ========================================================

      if (pendingDose.alarmDateTime.isAfter(now)) {
        return 0;
      }

      // ========================================================
      // 5. BUSCAR ÚLTIMA ACCIÓN REAL
      //
      // MISSED NO CUENTA.
      // ========================================================

      final lastActionResult = await txn.query(
        'dose_history',
        where: 'treatmentId = ? AND status IN (?, ?)',
        whereArgs: [treatment.id, 'ADMINISTERED', 'OMITTED'],
        orderBy: 'id DESC',
        limit: 1,
      );

      // ========================================================
      // 6. ESTABLECER CURSOR
      // ========================================================

      DateTime timelineCursor;

      if (lastActionResult.isNotEmpty) {
        final scheduledText = lastActionResult.first['scheduledDateTime']
            ?.toString();

        if (scheduledText == null || scheduledText.isEmpty) {
          timelineCursor = treatment.startDate.subtract(
            Duration(hours: treatment.frequencyHours),
          );
        } else {
          timelineCursor = DateTime.parse(scheduledText);
        }
      } else {
        timelineCursor = treatment.startDate.subtract(
          Duration(hours: treatment.frequencyHours),
        );
      }

      // ========================================================
      // 7. GENERAR MISSED ANTERIORES
      //
      // Aquí está la recuperación de las dosis que quedaron
      // atrás.
      //
      // Ejemplo:
      //
      // 15:15 ADMINISTRADA
      // 16:15 MISSED
      // 17:15 MISSED
      // 18:15 MISSED
      // 19:15 ADMINISTRADA
      //
      // ========================================================

      DateTime tick = timelineCursor.add(
        Duration(hours: treatment.frequencyHours),
      );

      while (tick.isBefore(pendingDose.scheduledDateTime)) {
        if (tick.isAfter(treatment.endDate)) {
          break;
        }

        await _insertMissedIfNeeded(txn, treatment, tick);

        tick = tick.add(Duration(hours: treatment.frequencyHours));
      }

      // ========================================================
      // 8. REGISTRAR ACCIÓN DEL USUARIO
      // ========================================================

      await txn.insert('dose_history', {
        'patientId': pendingDose.patientId,
        'treatmentId': pendingDose.treatmentId,
        'scheduledDateTime': pendingDose.scheduledDateTime.toIso8601String(),
        'administeredDateTime': userStatus == 'ADMINISTERED'
            ? now.toIso8601String()
            : null,
        'status': userStatus,
      });

      // ========================================================
      // 9. ELIMINAR PENDING ACTUAL
      // ========================================================

      await txn.delete(
        'pending_doses',
        where: 'id = ?',
        whereArgs: [pendingDoseId],
      );

      // ========================================================
      // 10. DETERMINAR SIGUIENTE DOSIS
      // ========================================================

      var nextScheduledDateTime = pendingDose.scheduledDateTime.add(
        Duration(hours: treatment.frequencyHours),
      );

      while (!nextScheduledDateTime.isAfter(now)) {
        if (nextScheduledDateTime.isAfter(treatment.endDate)) {
          await _finishTreatment(txn, treatment.id!);
          return 1;
        }

        await _insertMissedIfNeeded(txn, treatment, nextScheduledDateTime);

        nextScheduledDateTime = nextScheduledDateTime.add(
          Duration(hours: treatment.frequencyHours),
        );
      }

      if (nextScheduledDateTime.isAfter(treatment.endDate)) {
        await _finishTreatment(txn, treatment.id!);
        return 1;
      }

      await txn.insert('pending_doses', {
        'treatmentId': treatment.id,
        'patientId': treatment.patientId,
        'scheduledDateTime': nextScheduledDateTime.toIso8601String(),
        'alarmDateTime': nextScheduledDateTime.toIso8601String(),
        'status': 'PENDING',
      });

      return 1;
    });
  }

  // ============================================================
  // INSERTAR MISSED SI NO EXISTE
  // ============================================================

  Future<void> _insertMissedIfNeeded(
    DatabaseExecutor db,
    Treatment treatment,
    DateTime scheduledDateTime,
  ) async {
    if (scheduledDateTime.isAfter(treatment.endDate)) {
      return;
    }

    if (scheduledDateTime.isBefore(treatment.startDate)) {
      return;
    }

    final existing = await db.query(
      'dose_history',
      where: 'treatmentId = ? AND scheduledDateTime = ?',
      whereArgs: [treatment.id, scheduledDateTime.toIso8601String()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return;
    }

    await db.insert('dose_history', {
      'patientId': treatment.patientId,
      'treatmentId': treatment.id,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'administeredDateTime': null,
      'status': 'MISSED',
    });
  }

  // ============================================================
  // CREAR SIGUIENTE DOSIS PENDIENTE
  // ============================================================

  Future<PendingDose?> createNextPendingDose(PendingDose previousDose) async {
    final db = await _dbHelper.database;

    return db.transaction<PendingDose?>((txn) async {
      final treatmentRows = await txn.query(
        'treatments',
        where: 'id = ?',
        whereArgs: [previousDose.treatmentId],
        limit: 1,
      );

      if (treatmentRows.isEmpty) {
        return null;
      }

      final treatment = Treatment.fromMap(treatmentRows.first);

      if (treatment.id == null) {
        return null;
      }

      if (treatment.frequencyHours <= 0) {
        return null;
      }

      final nextDateTime = previousDose.scheduledDateTime.add(
        Duration(hours: treatment.frequencyHours),
      );

      if (nextDateTime.isAfter(treatment.endDate)) {
        await _finishTreatment(txn, treatment.id!);

        return null;
      }

      final existing = await txn.query(
        'pending_doses',
        where: 'treatmentId = ? AND status = ?',
        whereArgs: [treatment.id, 'PENDING'],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return PendingDose.fromMap(existing.first);
      }

      final now = DateTime.now();

      final alarmDateTime = nextDateTime.isAfter(now) ? nextDateTime : now;

      final id = await txn.insert('pending_doses', {
        'treatmentId': treatment.id,
        'patientId': treatment.patientId,
        'scheduledDateTime': nextDateTime.toIso8601String(),
        'alarmDateTime': alarmDateTime.toIso8601String(),
        'status': 'PENDING',
      });

      return PendingDose(
        id: id,
        treatmentId: treatment.id!,
        patientId: treatment.patientId,
        scheduledDateTime: nextDateTime,
        alarmDateTime: alarmDateTime,
        status: 'PENDING',
      );
    });
  }

  // ============================================================
  // DETALLE COMPLETO DE UNA PENDING DOSE
  // ============================================================

  Future<Map<String, dynamic>?> getPendingDoseDetail(int pendingDoseId) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        pd.id,
        pd.treatmentId,
        pd.patientId,
        pd.alarmDateTime,
        pd.scheduledDateTime,

        p.name AS patientName,

        m.name AS medicineName,

        t.doseAmount,
        t.doseUnit,
        t.totalDoses,

        (
          SELECT COUNT(*)
          FROM dose_history dh
          WHERE dh.treatmentId = t.id
        ) + 1 AS doseNumber

      FROM pending_doses pd

      INNER JOIN patients p
        ON p.id = pd.patientId

      INNER JOIN treatments t
        ON t.id = pd.treatmentId

      INNER JOIN medicines m
        ON m.id = t.medicineId

      WHERE pd.id = ?
        AND pd.status = 'PENDING'

      LIMIT 1
      ''',
      [pendingDoseId],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ============================================================
  // DETALLE DE LA PRÓXIMA PENDING DOSE
  // ============================================================

  Future<Map<String, dynamic>?> getNextPendingDoseDetail() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        pd.id,
        pd.treatmentId,
        pd.patientId,
        pd.alarmDateTime,
        pd.scheduledDateTime,

        p.name AS patientName,

        m.name AS medicineName,

        t.doseAmount,
        t.doseUnit,
        t.totalDoses,

        (
          SELECT COUNT(*)
          FROM dose_history dh
          WHERE dh.treatmentId = t.id
        ) + 1 AS doseNumber

      FROM pending_doses pd

      INNER JOIN patients p
        ON p.id = pd.patientId

      INNER JOIN treatments t
        ON t.id = pd.treatmentId

      INNER JOIN medicines m
        ON m.id = t.medicineId

      WHERE pd.status = 'PENDING'

      ORDER BY pd.alarmDateTime ASC

      LIMIT 1
      ''');

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ============================================================
  // OBTENER PENDING DOSE POR ID
  // ============================================================

  Future<PendingDose?> _getPendingDoseById(int id) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'pending_doses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return PendingDose.fromMap(result.first);
  }

  // ============================================================
  // OBTENER TRATAMIENTO
  // ============================================================

  Future<Treatment?> _getTreatment(int treatmentId) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'treatments',
      where: 'id = ?',
      whereArgs: [treatmentId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Treatment.fromMap(result.first);
  }

  // ============================================================
  // FINALIZAR TRATAMIENTO
  // ============================================================

  Future<void> _finishTreatment(DatabaseExecutor db, int treatmentId) async {
    // ----------------------------------------------------------
    // Eliminar pendientes residuales.
    // ----------------------------------------------------------

    await db.delete(
      'pending_doses',
      where: 'treatmentId = ?',
      whereArgs: [treatmentId],
    );

    // ----------------------------------------------------------
    // Marcar tratamiento como inactivo.
    // ----------------------------------------------------------

    await db.update(
      'treatments',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [treatmentId],
    );
  }

  // ============================================================
  // REINICIAR BASE DE DATOS PARA PRUEBAS
  // ============================================================
  //
  // Cancela las alarmas y elimina:
  //
  //   1. pending_doses
  //   2. dose_history
  //   3. treatments
  //
  // NO elimina:
  //
  //   - patients
  //   - medicines
  //
  // ============================================================

  Future<void> resetTestDatabase() async {
    final db = await _dbHelper.database;

    // ----------------------------------------------------------
    // 1. CANCELAR TODAS LAS ALARMAS
    // ----------------------------------------------------------

    await AlarmService.instance.cancelAllAlarms();

    // ----------------------------------------------------------
    // 2. LIMPIAR LAS TRES TABLAS EN UNA TRANSACCIÓN
    // ----------------------------------------------------------

    await db.transaction((txn) async {
      await txn.delete('pending_doses');
      await txn.delete('dose_history');
      await txn.delete('treatments');
    });

    // ----------------------------------------------------------
    // 3. LIMPIAR EL ESTADO DEL MONITOR
    // ----------------------------------------------------------

    AlarmBootstrapService.instance.resetMonitorState();
  }
}
