import '../database/database_helper.dart';
import '../models/treatment.dart';

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

      // Solo se crea el tratamiento. La primera dosis pendiente
      // se creará cuando la app esté abierta y llegue su hora.
      return await db.insert('treatments', treatment.toMap());
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

    return db.update(
      'treatments',
      treatment.toMap(),
      where: 'id = ?',
      whereArgs: [treatment.id],
    );
  }

  Future<int> deleteTreatment(int id) async {
    final db = await _dbHelper.database;

    return db.delete('treatments', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> setTreatmentActive(int id, bool active) async {
    final db = await _dbHelper.database;

    return db.update(
      'treatments',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
