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
  static const _dbName = 'cycles.db';
  static const _dbVersion = 11; // Added auto_lock to settings

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> closeDB() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
  
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await closeDB();
    await databaseFactory.deleteDatabase(path);
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), _dbName);
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
    await _onUpgrade(db, 0, version);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) { // Fresh install case or from onCreate
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
      
      await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY,
        user_name TEXT,
        user_email TEXT,
        user_password TEXT,
        user_pin TEXT NOT NULL,
        user_phone TEXT,
        user_role TEXT,
        user_status INTEGER,
        user_created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        user_updated_at TEXT,
        access_empreinte INTEGER
      )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute('''
      CREATE TABLE hydration (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        goal_met INTEGER DEFAULT 0
      )
      ''');
    }

    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN auto_lock INTEGER DEFAULT 0');
      } catch (_) {
        // Column may already exist
      }
    }
  }

  // User CRUD
  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert('users', {'user_id': 1, ...user}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<bool> hasUser() async {
    final user = await getUser();
    return user != null;
  }

  Future<int> updateUserPin(String newPin) async {
    final db = await database;
    return await db.update('users', {'user_pin': newPin}, where: 'user_id = ?', whereArgs: [1]);
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.update('users', user, where: 'user_id = ?', whereArgs: [1]);
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

  // Hydration CRUD
  Future<int> insertHydration(Map<String, dynamic> hydration) async {
    final db = await database;
    return await db.insert('hydration', hydration);
  }

  Future<List<Map<String, dynamic>>> getHydrationForDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    return await db.query('hydration', where: "date LIKE ?", whereArgs: ["$dateStr%"]);
  }

  Future<double> getTodayTotalHydration() async {
    final now = DateTime.now();
    final dateStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM hydration WHERE date LIKE ?', ["$dateStr%"]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getHydrationHistory(int limit) async {
    final db = await database;
    return await db.query('hydration', orderBy: 'date DESC', limit: limit);
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
