import '../database/database_helper.dart';
import '../models/patient.dart';

class PatientService {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  Future<Patient?> getPatientById(int id) async {
    final db = await _databaseHelper.database;

    final result = await db.query('patients', where: 'id = ?', whereArgs: [id]);

    if (result.isNotEmpty) {
      return Patient.fromMap(result.first);
    }

    return null;
  }

  Future<int> insertPatient(Patient patient) async {
    final db = await _databaseHelper.database;

    return await db.insert('patients', patient.toMap());
  }

  Future<List<Patient>> getPatients() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> maps = await db.query('patients');

    return maps.map((e) => Patient.fromMap(e)).toList();
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await _databaseHelper.database;

    return await db.update(
      'patients',
      patient.toMap(),
      where: 'id=?',
      whereArgs: [patient.id],
    );
  }

  Future<int> deletePatient(int id) async {
    final db = await _databaseHelper.database;

    return await db.delete('patients', where: 'id=?', whereArgs: [id]);
  }
}
