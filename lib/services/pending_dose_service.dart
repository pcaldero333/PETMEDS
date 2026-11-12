import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/pending_dose.dart';
import '../models/treatment.dart';
import '../models/dose_history.dart';
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
    final now = DateTime.now().toIso8601String();

    final rows = await db.query(
      'pending_doses',
      where: 'status = ? AND alarmDateTime > ?',
      whereArgs: ['PENDING', now],
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
  // Se mantiene como máximo una dosis PENDING por tratamiento.
  //
  // Si hay varias dosis vencidas sin resolver, se crea la última
  // que ya debería haber ocurrido. Al resolverla, los horarios
  // anteriores sin resolver se guardan como MISSED.
  //
  // Los horarios se calculan desde treatment.startDate, usando
  // frequencyHours. El paso del tiempo por sí solo no crea MISSED.
  //
  // ============================================================

  Future<List<PendingDose>> createDuePendingDoses() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    return db.transaction<List<PendingDose>>((txn) async {
      final treatmentRows = await txn.query(
        'treatments',
        where: 'active = ?',
        whereArgs: [1],
      );

      final createdDoses = <PendingDose>[];

      for (final row in treatmentRows) {
        final treatment = Treatment.fromMap(row);

        if (treatment.id == null || treatment.frequencyHours <= 0) {
          continue;
        }

        if (treatment.endDate.isBefore(treatment.startDate)) {
          await _finishTreatment(txn, treatment.id!);
          continue;
        }

        final existingPending = await txn.query(
          'pending_doses',
          where: 'treatmentId = ? AND status = ?',
          whereArgs: [treatment.id, 'PENDING'],
          limit: 1,
        );

        final historyRows = await txn.query(
          'dose_history',
          columns: ['scheduledDateTime'],
          where: 'treatmentId = ?',
          whereArgs: [treatment.id],
        );

        final processedScheduleTimes = historyRows
            .map((historyRow) => historyRow['scheduledDateTime']?.toString())
            .whereType<String>()
            .toSet();

        DateTime? latestUnprocessedDueTick;
        DateTime? firstUnprocessedFutureTick;

        var tick = treatment.startDate;

        while (!tick.isAfter(treatment.endDate)) {
          final tickKey = tick.toIso8601String();

          if (!processedScheduleTimes.contains(tickKey)) {
            if (!tick.isAfter(now)) {
              latestUnprocessedDueTick = tick;
            } else {
              firstUnprocessedFutureTick ??= tick;
            }
          }

          tick = tick.add(Duration(hours: treatment.frequencyHours));
        }

        final scheduledDateTime =
            latestUnprocessedDueTick ?? firstUnprocessedFutureTick;

        if (scheduledDateTime == null) {
          await txn.delete(
            'pending_doses',
            where: 'treatmentId = ? AND status = ?',
            whereArgs: [treatment.id, 'PENDING'],
          );
          await _finishTreatment(txn, treatment.id!);
          continue;
        }

        // Si el usuario pospuso una dosis, respetar esa hora de alarma.
        // En los demás casos, una pendiente antigua no debe provocar que
        // PETMEDS presente cada horario vencido uno por uno.
        if (existingPending.isNotEmpty) {
          final pending = PendingDose.fromMap(existingPending.first);

          if (pending.alarmDateTime.isAfter(now)) {
            continue;
          }

          if (latestUnprocessedDueTick != null &&
              pending.scheduledDateTime.isBefore(latestUnprocessedDueTick)) {
            var missedTick = treatment.startDate;

            while (missedTick.isBefore(latestUnprocessedDueTick)) {
              if (!processedScheduleTimes.contains(
                missedTick.toIso8601String(),
              )) {
                await _insertMissedIfNeeded(txn, treatment, missedTick);
              }

              missedTick = missedTick.add(
                Duration(hours: treatment.frequencyHours),
              );
            }

            await txn.update(
              'pending_doses',
              {
                'scheduledDateTime': latestUnprocessedDueTick.toIso8601String(),
                'alarmDateTime': now.toIso8601String(),
              },
              where: 'id = ? AND status = ?',
              whereArgs: [pending.id, 'PENDING'],
            );

            createdDoses.add(
              pending.copyWith(
                scheduledDateTime: latestUnprocessedDueTick,
                alarmDateTime: now,
              ),
            );
          }

          continue;
        }

        // Registrar los horarios anteriores al más reciente como MISSED.
        // La dosis más reciente vencida queda disponible para el usuario.
        if (latestUnprocessedDueTick != null) {
          var missedTick = treatment.startDate;

          while (missedTick.isBefore(latestUnprocessedDueTick)) {
            if (!processedScheduleTimes.contains(
              missedTick.toIso8601String(),
            )) {
              await _insertMissedIfNeeded(txn, treatment, missedTick);
            }

            missedTick = missedTick.add(
              Duration(hours: treatment.frequencyHours),
            );
          }
        }

        final alarmDateTime = scheduledDateTime.isAfter(now)
            ? scheduledDateTime
            : now;

        final id = await txn.insert('pending_doses', {
          'treatmentId': treatment.id,
          'patientId': treatment.patientId,
          'scheduledDateTime': scheduledDateTime.toIso8601String(),
          'alarmDateTime': alarmDateTime.toIso8601String(),
          'status': 'PENDING',
        });

        createdDoses.add(
          PendingDose(
            id: id,
            treatmentId: treatment.id!,
            patientId: treatment.patientId,
            scheduledDateTime: scheduledDateTime,
            alarmDateTime: alarmDateTime,
            status: 'PENDING',
          ),
        );
      }

      return createdDoses;
    });
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

    return db.transaction<int>((txn) async {
      final treatmentRows = await txn.query(
        'treatments',
        where: 'id = ?',
        whereArgs: [treatmentId],
        limit: 1,
      );

      if (treatmentRows.isEmpty) {
        return 0;
      }

      final treatment = Treatment.fromMap(treatmentRows.first);

      if (treatment.id == null || treatment.frequencyHours <= 0) {
        return 0;
      }

      if (!_isValidScheduledTick(treatment, scheduledDateTime)) {
        if (scheduledDateTime.isAfter(treatment.endDate)) {
          await _finishTreatment(txn, treatmentId);
        }
        return 0;
      }

      final existingPending = await txn.query(
        'pending_doses',
        where: 'treatmentId = ? AND status = ?',
        whereArgs: [treatmentId, 'PENDING'],
        limit: 1,
      );

      if (existingPending.isNotEmpty) {
        return existingPending.first['id'] as int;
      }

      final existingHistory = await txn.query(
        'dose_history',
        where: 'treatmentId = ? AND scheduledDateTime = ?',
        whereArgs: [treatmentId, scheduledDateTime.toIso8601String()],
        limit: 1,
      );

      if (existingHistory.isNotEmpty) {
        return 0;
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

      return txn.insert('pending_doses', pendingDose.toMap());
    });
  }

  // ============================================================
  // POSPONER DOSIS
  // ============================================================
  //
  // No modifica scheduledDateTime.
  // No crea historial.
  // No genera MISSED.
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
  // Solo se marcan MISSED los horarios anteriores a la dosis que
  // el usuario está resolviendo. Los horarios posteriores nunca
  // se marcan MISSED al resolver una dosis anterior.
  //
  // ============================================================

  Future<int> _resolveDose(int pendingDoseId, String userStatus) async {
    final db = await _dbHelper.database;

    final result = await db.transaction<int>((txn) async {
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

      if (treatment.id == null || treatment.frequencyHours <= 0) {
        return 0;
      }

      if (pendingDose.scheduledDateTime.isAfter(treatment.endDate)) {
        await txn.delete(
          'pending_doses',
          where: 'id = ?',
          whereArgs: [pendingDoseId],
        );

        await _finishTreatment(txn, treatment.id!);
        return 0;
      }

      if (!_isValidScheduledTick(treatment, pendingDose.scheduledDateTime)) {
        return 0;
      }

      final now = DateTime.now();

      // La alarma puede haberse pospuesto. La dosis no se resuelve
      // hasta que llegue alarmDateTime.
      if (pendingDose.alarmDateTime.isAfter(now)) {
        return 0;
      }

      // Evita crear una segunda entrada de historial para el mismo
      // horario si existe una dosis pendiente duplicada antigua.
      final existingHistory = await txn.query(
        'dose_history',
        where: 'treatmentId = ? AND scheduledDateTime = ?',
        whereArgs: [
          treatment.id,
          pendingDose.scheduledDateTime.toIso8601String(),
        ],
        limit: 1,
      );

      if (existingHistory.isNotEmpty) {
        await txn.delete(
          'pending_doses',
          where: 'id = ?',
          whereArgs: [pendingDoseId],
        );
        return 0;
      }

      // Busca la última acción real anterior a esta dosis.
      // Las entradas MISSED no cambian este cursor.
      final lastActionResult = await txn.query(
        'dose_history',
        where: 'treatmentId = ? AND status IN (?, ?) AND scheduledDateTime < ?',
        whereArgs: [
          treatment.id,
          'ADMINISTERED',
          'OMITTED',
          pendingDose.scheduledDateTime.toIso8601String(),
        ],
        orderBy: 'scheduledDateTime DESC, id DESC',
        limit: 1,
      );

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

      // Registra como MISSED únicamente los horarios entre la última
      // acción y la dosis que el usuario está resolviendo.
      var tick = timelineCursor.add(Duration(hours: treatment.frequencyHours));

      while (tick.isBefore(pendingDose.scheduledDateTime)) {
        if (tick.isAfter(treatment.endDate)) {
          break;
        }

        await _insertMissedIfNeeded(txn, treatment, tick);
        tick = tick.add(Duration(hours: treatment.frequencyHours));
      }

      await txn.insert('dose_history', {
        'patientId': pendingDose.patientId,
        'treatmentId': pendingDose.treatmentId,
        'scheduledDateTime': pendingDose.scheduledDateTime.toIso8601String(),
        'administeredDateTime': userStatus == 'ADMINISTERED'
            ? now.toIso8601String()
            : null,
        'status': userStatus,
      });

      await txn.delete(
        'pending_doses',
        where: 'id = ?',
        whereArgs: [pendingDoseId],
      );

      // La siguiente dosis siempre conserva el horario anclado:
      // dosis actual + frecuencia. Si está vencida, se presenta ahora,
      // pero scheduledDateTime no se cambia.
      var nextScheduledDateTime = pendingDose.scheduledDateTime.add(
        Duration(hours: treatment.frequencyHours),
      );

      while (!nextScheduledDateTime.isAfter(treatment.endDate)) {
        final alreadyProcessed = await txn.query(
          'dose_history',
          where: 'treatmentId = ? AND scheduledDateTime = ?',
          whereArgs: [treatment.id, nextScheduledDateTime.toIso8601String()],
          limit: 1,
        );

        if (alreadyProcessed.isEmpty) {
          break;
        }

        nextScheduledDateTime = nextScheduledDateTime.add(
          Duration(hours: treatment.frequencyHours),
        );
      }

      if (nextScheduledDateTime.isAfter(treatment.endDate)) {
        await _finishTreatment(txn, treatment.id!);
        return 1;
      }

      // Protección adicional ante pendientes duplicadas que pudieran
      // existir desde antes de esta versión.
      final anotherPending = await txn.query(
        'pending_doses',
        where: 'treatmentId = ? AND status = ?',
        whereArgs: [treatment.id, 'PENDING'],
        orderBy: 'scheduledDateTime ASC',
        limit: 1,
      );

      if (anotherPending.isNotEmpty) {
        return 1;
      }

      final nextAlarmDateTime = nextScheduledDateTime.isAfter(now)
          ? nextScheduledDateTime
          : now;

      await txn.insert('pending_doses', {
        'treatmentId': treatment.id,
        'patientId': treatment.patientId,
        'scheduledDateTime': nextScheduledDateTime.toIso8601String(),
        'alarmDateTime': nextAlarmDateTime.toIso8601String(),
        'status': 'PENDING',
      });

      return 1;
    });

    if (result > 0) {
      await createDuePendingDoses();
    }

    return result;
  }

  // ============================================================
  // INSERTAR MISSED SI NO EXISTE
  // ============================================================

  Future<void> _insertMissedIfNeeded(
    DatabaseExecutor db,
    Treatment treatment,
    DateTime scheduledDateTime,
  ) async {
    if (treatment.id == null || treatment.frequencyHours <= 0) {
      return;
    }

    if (!_isValidScheduledTick(treatment, scheduledDateTime)) {
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

      if (treatment.id == null || treatment.frequencyHours <= 0) {
        return null;
      }

      final existingPending = await txn.query(
        'pending_doses',
        where: 'treatmentId = ? AND status = ?',
        whereArgs: [treatment.id, 'PENDING'],
        orderBy: 'scheduledDateTime ASC',
        limit: 1,
      );

      if (existingPending.isNotEmpty) {
        return PendingDose.fromMap(existingPending.first);
      }

      var nextDateTime = previousDose.scheduledDateTime.add(
        Duration(hours: treatment.frequencyHours),
      );

      while (!nextDateTime.isAfter(treatment.endDate)) {
        final existingHistory = await txn.query(
          'dose_history',
          where: 'treatmentId = ? AND scheduledDateTime = ?',
          whereArgs: [treatment.id, nextDateTime.toIso8601String()],
          limit: 1,
        );

        if (existingHistory.isEmpty) {
          break;
        }

        nextDateTime = nextDateTime.add(
          Duration(hours: treatment.frequencyHours),
        );
      }

      if (nextDateTime.isAfter(treatment.endDate)) {
        await _finishTreatment(txn, treatment.id!);
        return null;
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
  // OBTENER HISTORIAL DE DOSIS
  // ============================================================

  Future<List<DoseHistory>> getDoseHistory() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        dh.id,
        dh.patientId,
        dh.treatmentId,
        dh.scheduledDateTime,
        dh.administeredDateTime,
        dh.status,

        p.name AS patientName,

        m.name AS medicineName,

        t.doseAmount,
        t.doseUnit

      FROM dose_history dh

      INNER JOIN patients p
        ON p.id = dh.patientId

      INNER JOIN treatments t
        ON t.id = dh.treatmentId

      INNER JOIN medicines m
        ON m.id = t.medicineId

      ORDER BY dh.scheduledDateTime DESC
    ''');

    return result.map((map) => DoseHistory.fromMap(map)).toList();
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
  // VALIDAR QUE LA FECHA PERTENEZCA AL HORARIO DEL TRATAMIENTO
  // ============================================================

  bool _isValidScheduledTick(Treatment treatment, DateTime scheduledDateTime) {
    if (treatment.frequencyHours <= 0) {
      return false;
    }

    if (scheduledDateTime.isBefore(treatment.startDate) ||
        scheduledDateTime.isAfter(treatment.endDate)) {
      return false;
    }

    final intervalMicroseconds = Duration(
      hours: treatment.frequencyHours,
    ).inMicroseconds;
    final elapsedMicroseconds = scheduledDateTime
        .difference(treatment.startDate)
        .inMicroseconds;

    if (intervalMicroseconds <= 0 || elapsedMicroseconds < 0) {
      return false;
    }

    return elapsedMicroseconds % intervalMicroseconds == 0;
  }

  // ============================================================
  // FINALIZAR TRATAMIENTO
  // ============================================================

  Future<void> _finishTreatment(DatabaseExecutor db, int treatmentId) async {
    await db.delete(
      'pending_doses',
      where: 'treatmentId = ?',
      whereArgs: [treatmentId],
    );

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
  // No elimina:
  //
  //   - patients
  //   - medicines
  //
  // ============================================================

  Future<void> resetTestDatabase() async {
    final db = await _dbHelper.database;

    await AlarmService.instance.cancelAllAlarms();

    await db.transaction((txn) async {
      await txn.delete('pending_doses');
      await txn.delete('dose_history');
      await txn.delete('treatments');
    });

    AlarmBootstrapService.instance.resetMonitorState();
  }
}
