import '../database/database_helper.dart';
import '../models/treatment.dart';

class TreatmentService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ============================================================
  // AGREGAR TRATAMIENTO
  // ============================================================
  //
  // Regla de negocio:
  //
  // Para una misma combinación:
  //     patientId + medicineId
  //
  // el nuevo tratamiento solamente puede comenzar DESPUÉS
  // del último tratamiento existente de esa misma combinación.
  //
  // Ejemplo válido:
  //
  // 08/08 06:00 -> 15/08 06:00
  // 16/08 06:00 -> 24/08 06:00
  //
  // Ejemplo NO válido:
  //
  // 08/08 06:00 -> 15/08 06:00
  // 15/08 06:00 -> 24/08 06:00
  //
  // Retorno:
  //   > 0 = ID del tratamiento creado
  //   -1  = existe solapamiento
  //   -2  = error de base de datos
  //
  Future<int> insertTreatment(Treatment treatment) async {
    final db = await _dbHelper.database;

    try {
      // ----------------------------------------------------------
      // Buscar el tratamiento existente más reciente para la
      // misma mascota y el mismo medicamento.
      // ----------------------------------------------------------

      final existing = await db.query(
        'treatments',
        where: 'patientId = ? AND medicineId = ?',
        whereArgs: [treatment.patientId, treatment.medicineId],
        orderBy: 'endDate DESC',
        limit: 1,
      );

      // ----------------------------------------------------------
      // Si ya existe un tratamiento, comprobamos que el nuevo
      // comience estrictamente después de su fecha de finalización.
      // ----------------------------------------------------------

      if (existing.isNotEmpty) {
        final lastTreatment = Treatment.fromMap(existing.first);

        if (!treatment.startDate.isAfter(lastTreatment.endDate)) {
          return -1;
        }
      }

      // ----------------------------------------------------------
      // No existe conflicto. Insertamos el nuevo tratamiento.
      // ----------------------------------------------------------

      return await db.insert('treatments', treatment.toMap());
    } catch (_) {
      return -2;
    }
  }

  // ============================================================
  // OBTENER TODOS LOS TRATAMIENTOS
  // ============================================================

  Future<List<Treatment>> getTreatments() async {
    final db = await _dbHelper.database;

    final result = await db.query('treatments', orderBy: 'startDate ASC');

    return result.map((map) => Treatment.fromMap(map)).toList();
  }

  // ============================================================
  // OBTENER TRATAMIENTO POR ID
  // ============================================================

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

  // ============================================================
  // OBTENER TRATAMIENTOS DE UNA MASCOTA
  // ============================================================

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

  // ============================================================
  // ACTUALIZAR TRATAMIENTO
  // ============================================================

  Future<int> updateTreatment(Treatment treatment) async {
    final db = await _dbHelper.database;

    return await db.update(
      'treatments',
      treatment.toMap(),
      where: 'id = ?',
      whereArgs: [treatment.id],
    );
  }

  // ============================================================
  // ELIMINAR TRATAMIENTO
  // ============================================================

  Future<int> deleteTreatment(int id) async {
    final db = await _dbHelper.database;

    return await db.delete('treatments', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================
  // ACTIVAR / DESACTIVAR TRATAMIENTO
  // ============================================================

  Future<int> setTreatmentActive(int id, bool active) async {
    final db = await _dbHelper.database;

    return await db.update(
      'treatments',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
