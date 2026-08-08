import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('petmeds.db');

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS patients');
        await db.execute('DROP TABLE IF EXISTS medicines');
        await db.execute('DROP TABLE IF EXISTS treatments');
        await db.execute('DROP TABLE IF EXISTS dose_history');

        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE patients(

id INTEGER PRIMARY KEY AUTOINCREMENT,

name TEXT NOT NULL,

species TEXT NOT NULL,

breed TEXT,

sex TEXT,

birthDate TEXT,

weight REAL,

ownerName TEXT NOT NULL,

ownerPhone TEXT,

notes TEXT,

photoPath TEXT

);
''');

    await db.execute('''
CREATE TABLE medicines(

id INTEGER PRIMARY KEY AUTOINCREMENT,

name TEXT NOT NULL,

presentation TEXT,

concentration TEXT,

observations TEXT

)
''');

    await db.execute('''
CREATE TABLE treatments(

id INTEGER PRIMARY KEY AUTOINCREMENT,

patientId INTEGER,

medicineId INTEGER,

startDate TEXT,

frequencyHours INTEGER,

totalDoses INTEGER,

remainingDoses INTEGER,

active INTEGER

)
''');

    await db.execute('''
CREATE TABLE dose_history(

id INTEGER PRIMARY KEY AUTOINCREMENT,

patientId INTEGER,

treatmentId INTEGER,

doseDate TEXT,

status TEXT

)
''');
  }
}
