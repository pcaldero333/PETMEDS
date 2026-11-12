import '../database/database_helper.dart';

class ParameterService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ============================================================
  // OBTENER PARÁMETRO
  // ============================================================

  Future<String?> getParameter(String name) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'parameters',
      columns: ['value'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['value']?.toString();
  }

  // ============================================================
  // GUARDAR PARÁMETRO
  // ============================================================

  Future<void> setParameter(String name, String value) async {
    final db = await _dbHelper.database;

    final updated = await db.update(
      'parameters',
      {'value': value},
      where: 'name = ?',
      whereArgs: [name],
    );

    if (updated == 0) {
      await db.insert('parameters', {'name': name, 'value': value});
    }
  }

  // ============================================================
  // NOTIFICACIONES ACTIVADAS
  // ============================================================

  Future<bool> areNotificationsEnabled() async {
    final value = await getParameter('notificationsEnabled');

    // Si por alguna razón no existe todavía,
    // asumimos que están activadas.
    if (value == null) {
      return true;
    }

    return value == '1';
  }

  // ============================================================
  // ACTIVAR / DESACTIVAR NOTIFICACIONES
  // ============================================================

  Future<void> setNotificationsEnabled(bool enabled) async {
    await setParameter('notificationsEnabled', enabled ? '1' : '0');
  }

  // ============================================================
  // OBTENER TIEMPO DE POSPOSICIÓN
  // ============================================================

  Future<int> getPostponeMinutes() async {
    final value = await getParameter('postponeMinutes');

    final minutes = int.tryParse(value ?? '');

    if (minutes == null) {
      return 15;
    }

    const allowed = [5, 10, 15, 30];

    if (!allowed.contains(minutes)) {
      return 15;
    }

    return minutes;
  }

  // ============================================================
  // GUARDAR TIEMPO DE POSPOSICIÓN
  // ============================================================

  Future<void> setPostponeMinutes(int minutes) async {
    const allowed = [5, 10, 15, 30];

    if (!allowed.contains(minutes)) {
      return;
    }

    await setParameter('postponeMinutes', minutes.toString());
  }
}
