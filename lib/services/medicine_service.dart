import '../database/database_helper.dart';
import '../models/medicine.dart';

class MedicineService {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insertMedicine(Medicine medicine) async {
    final db = await _databaseHelper.database;

    return await db.insert('medicines', medicine.toMap());
  }

  Future<List<Medicine>> getMedicines() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'medicines',
      orderBy: 'name ASC',
    );

    return maps.map((e) => Medicine.fromMap(e)).toList();
  }

  Future<Medicine?> getMedicineById(int id) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return Medicine.fromMap(result.first);
    }

    return null;
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await _databaseHelper.database;

    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await _databaseHelper.database;

    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }
}
