import '../database/database_helper.dart';
import '../models/treatment.dart';
import 'alarm_bootstrap_service.dart';
import 'alarm_service.dart';

class TreatmentService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertTreatment(Treatment treatment) async {
    final db = await _dbHelper.database;

    try {
      final existing = await db.query(
        'treatments',
        where: 'patientId = ? AND medicineId = ?',
        whereArgs: [treatment.patientId, treatment.medicineId],
        orderBy: 'endDate DESC',
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final lastTreatment = Treatment.fromMap(existing.first);

        if (!treatment.startDate.isAfter(lastTreatment.endDate)) {
          return -1;
        }
      }

      final id = await db.insert('treatments', treatment.toMap());
      await _refreshAlarms();
      return id;
    } catch (_) {
      return -2;
    }
  }

  Future<List<Treatment>> getTreatments() async {
    final db = await _dbHelper.database;

    final result = await db.query('treatments', orderBy: 'startDate ASC');

    return result.map((map) => Treatment.fromMap(map)).toList();
  }

  Future<Treatment?> getTreatmentById(int id) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'treatments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Treatment.fromMap(result.first);
  }

  Future<List<Treatment>> getTreatmentsByPatient(int patientId) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'treatments',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'startDate ASC',
    );

    return result.map((map) => Treatment.fromMap(map)).toList();
  }

  Future<int> updateTreatment(Treatment treatment) async {
    final db = await _dbHelper.database;

    final pendingRows = await db.query(
      'pending_doses',
      columns: ['id'],
      where: 'treatmentId = ?',
      whereArgs: [treatment.id],
    );
    for (final row in pendingRows) {
      await AlarmService.instance.cancelAlarm(row['id'] as int?);
    }

    final updated = await db.update(
      'treatments',
      treatment.toMap(),
      where: 'id = ?',
      whereArgs: [treatment.id],
    );

    if (updated > 0) {
      await db.delete(
        'pending_doses',
        where: 'treatmentId = ?',
        whereArgs: [treatment.id],
      );
      await _refreshAlarms();
    }

    return updated;
  }

  Future<int> deleteTreatment(int id) async {
    final db = await _dbHelper.database;

    final pendingRows = await db.query(
      'pending_doses',
      columns: ['id'],
      where: 'treatmentId = ?',
      whereArgs: [id],
    );
    for (final row in pendingRows) {
      await AlarmService.instance.cancelAlarm(row['id'] as int?);
    }
    await db.delete('pending_doses', where: 'treatmentId = ?', whereArgs: [id]);

    final deleted = await db.delete('treatments', where: 'id = ?', whereArgs: [id]);
    await _refreshAlarms();
    return deleted;
  }

  Future<int> setTreatmentActive(int id, bool active) async {
    final db = await _dbHelper.database;

    final updated = await db.update(
      'treatments',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (!active) {
      final pendingRows = await db.query(
        'pending_doses',
        columns: ['id'],
        where: 'treatmentId = ?',
        whereArgs: [id],
      );
      for (final row in pendingRows) {
        await AlarmService.instance.cancelAlarm(row['id'] as int?);
      }
      await db.delete('pending_doses', where: 'treatmentId = ?', whereArgs: [id]);
    }
    await _refreshAlarms();
    return updated;
  }

  Future<void> _refreshAlarms() async {
    try {
      await AlarmBootstrapService.instance.refresh();
    } catch (_) {
      // La escritura del tratamiento ya se completó; un fallo del sistema
      // de notificaciones no debe reportarla como fallida ni revertirla.
    }
  }
}
