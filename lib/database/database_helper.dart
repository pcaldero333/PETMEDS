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

    return openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
      )
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
        patientId INTEGER NOT NULL,
        medicineId INTEGER NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        frequencyHours INTEGER NOT NULL,
        doseAmount REAL NOT NULL,
        doseUnit TEXT NOT NULL,
        totalDoses INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE dose_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientId INTEGER NOT NULL,
        treatmentId INTEGER NOT NULL,
        scheduledDateTime TEXT NOT NULL,
        administeredDateTime TEXT,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_doses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        treatmentId INTEGER NOT NULL UNIQUE,
        patientId INTEGER NOT NULL,
        scheduledDateTime TEXT NOT NULL,
        alarmDateTime TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    await db.execute('''
      CREATE TABLE parameters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');

    await db.insert('parameters', {'name': 'postponeMinutes', 'value': '15'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE pending_doses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          treatmentId INTEGER NOT NULL UNIQUE,
          patientId INTEGER NOT NULL,
          scheduledDateTime TEXT NOT NULL,
          alarmDateTime TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'PENDING'
        )
      ''');
    }

    // Versión 7:
    // La aplicación deja de crear dosis futuras o alarmas programadas.
    // No se borra ningún dato existente durante esta migración.
  }
}
