import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cycle.dart';
import '../models/symptom.dart';
import '../models/note.dart';
import '../models/settings.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const _dbVersion = 6; // Database version

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'cycles.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE cycles(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      start_date TEXT NOT NULL,
      end_date TEXT,
      period_end_date TEXT,
      cycle_length INTEGER,
      ovulation_date TEXT,
      expected_period TEXT,
      phase TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''');

    await db.execute('''
    CREATE TABLE symptoms(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cycle_id INTEGER,
      date TEXT NOT NULL,
      mood TEXT,
      pain_level INTEGER,
      energy_level INTEGER,
      libido_level INTEGER,
      notes TEXT,
      FOREIGN KEY (cycle_id) REFERENCES cycles(id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      content TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE settings (
      id INTEGER PRIMARY KEY,
      default_cycle_length INTEGER,
      notify_period INTEGER,
      notify_ovulation INTEGER,
      theme TEXT
    )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // A simple, destructive migration for development.
    await db.execute('DROP TABLE IF EXISTS cycles');
    await db.execute('DROP TABLE IF EXISTS symptoms');
    await db.execute('DROP TABLE IF EXISTS notes');
    await db.execute('DROP TABLE IF EXISTS settings');
    await _onCreate(db, newVersion);
  }

  // Cycle CRUD methods
  Future<int> insertCycle(Cycle cycle) async {
    final db = await database;
    return await db.insert('cycles', cycle.toMap());
  }

  Future<List<Cycle>> getCycles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cycles', orderBy: 'start_date DESC');
    return List.generate(maps.length, (i) => Cycle.fromMap(maps[i]));
  }

  Future<int> updateCycle(Cycle cycle) async {
    final db = await database;
    return await db.update('cycles', cycle.toMap(), where: 'id = ?', whereArgs: [cycle.id]);
  }

  Future<int> deleteCycle(int id) async {
    final db = await database;
    return await db.delete('cycles', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<double?> getAverageCycleLength() async {
    final db = await database;
    final result = await db.rawQuery('SELECT AVG(cycle_length) as avg FROM cycles WHERE cycle_length IS NOT NULL AND cycle_length > 0');
    return result.first['avg'] as double?;
  }

  // Symptom CRUD
  Future<int> insertSymptom(Symptom symptom) async {
    final db = await database;
    return await db.insert('symptoms', symptom.toMap());
  }

  Future<List<Symptom>> getSymptomsForCycle(int cycleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('symptoms', where: 'cycle_id = ?', whereArgs: [cycleId]);
    return List.generate(maps.length, (i) => Symptom.fromMap(maps[i]));
  }
  
  Future<List<Symptom>> getAllSymptoms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('symptoms');
    return List.generate(maps.length, (i) => Symptom.fromMap(maps[i]));
  }

  Future<int> updateSymptom(Symptom symptom) async {
    final db = await database;
    return await db.update('symptoms', symptom.toMap(), where: 'id = ?', whereArgs: [symptom.id]);
  }

  Future<int> deleteSymptom(int id) async {
    final db = await database;
    return await db.delete('symptoms', where: 'id = ?', whereArgs: [id]);
  }

  // Note CRUD
  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // Settings CRUD
  Future<int> updateSettings(AppSettings settings) async {
    final db = await database;
    return await db.update('settings', settings.toMap(), where: 'id = ?', whereArgs: [settings.id]);
  }

  Future<AppSettings> getSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    if (maps.isNotEmpty) {
      return AppSettings.fromMap(maps.first);
    } else {
      final defaultSettings = AppSettings(id: 1);
      await db.insert('settings', defaultSettings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return defaultSettings;
    }
  }
}
