import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// Alias avoids a name clash — this file's class is also called DatabaseService
import 'package:mad_asgm/services/database/heart_rate_database_service.dart' as shared_db;
import '../../models/exercise_model/exercise_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'fitness_app.db');

    return await openDatabase(
      path,
      version: 4, // bumped from 3 → 4 to add user_id
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id              TEXT    PRIMARY KEY,
        user_id         INTEGER NOT NULL DEFAULT 1,
        title           TEXT    NOT NULL,
        type            INTEGER NOT NULL,
        startTime       TEXT    NOT NULL,
        durationMinutes INTEGER NOT NULL,
        distanceKm      REAL,
        energyExpended  INTEGER,
        steps           INTEGER,
        notes           TEXT,
        routePoints     TEXT,
        createdAt       TEXT    NOT NULL,
        stepGoal        INTEGER,
        distanceGoal    REAL,
        timeGoal        INTEGER,
        isAutoDetected  INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE exercises ADD COLUMN stepGoal INTEGER');
      await db.execute('ALTER TABLE exercises ADD COLUMN distanceGoal REAL');
      await db.execute('ALTER TABLE exercises ADD COLUMN timeGoal INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE exercises ADD COLUMN isAutoDetected INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      // Existing rows default to user 1 (the first registered / guest account)
      await db.execute(
        'ALTER TABLE exercises ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  // ── Current user ID ───────────────────────────────────────────────────────────
  // Reads from the shared DatabaseService which sets _currentUser on login.
  int get _currentUserId {
    try {
      return shared_db.DatabaseService.currentUserId;
    } catch (_) {
      return 1; // fallback — should never reach here after login
    }
  }

  // ── Insert ────────────────────────────────────────────────────────────────────

  Future<String> insertExercise(Exercise exercise) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final json = exercise.copyWith(id: id).toJson();
    json['user_id'] = _currentUserId; // ← tag with logged-in user

    await db.insert('exercises', json,
        conflictAlgorithm: ConflictAlgorithm.replace);

    return id;
  }

  // ── Read ──────────────────────────────────────────────────────────────────────

  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => Exercise.fromJson(m)).toList();
  }

  Future<Exercise?> getExerciseById(String id) async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
    );
    return maps.isEmpty ? null : Exercise.fromJson(maps.first);
  }

  Future<List<Exercise>> getExercisesByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'user_id = ? AND startTime >= ? AND startTime <= ?',
      whereArgs: [
        _currentUserId,
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => Exercise.fromJson(m)).toList();
  }

  Future<List<Exercise>> getExercisesByType(ExerciseType type) async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'user_id = ? AND type = ?',
      whereArgs: [_currentUserId, type.index],
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => Exercise.fromJson(m)).toList();
  }

  // ── Update ────────────────────────────────────────────────────────────────────

  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    final json = exercise.toJson();
    json['user_id'] = _currentUserId;

    return db.update(
      'exercises',
      json,
      where: 'id = ? AND user_id = ?',
      whereArgs: [exercise.id, _currentUserId],
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  Future<int> deleteExercise(String id) async {
    final db = await database;
    return db.delete(
      'exercises',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
    );
  }

  Future<int> deleteAllExercises() async {
    final db = await database;
    return db.delete(
      'exercises',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<int> getExerciseCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM exercises WHERE user_id = ?',
      [_currentUserId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}