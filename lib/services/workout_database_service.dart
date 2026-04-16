import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/workout_model.dart';
import '../models/workout_exercise_model.dart';

class WorkoutDatabaseService {
  static final WorkoutDatabaseService _instance = WorkoutDatabaseService._internal();
  static Database? _database;

  factory WorkoutDatabaseService() => _instance;
  WorkoutDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'workout_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workouts (
        id TEXT PRIMARY KEY,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        exerciseCount INTEGER,
        durationMinutes INTEGER,
        difficulty TEXT,
        color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_exercises (
        id TEXT PRIMARY KEY,
        workoutId TEXT NOT NULL,
        name TEXT NOT NULL,
        sets INTEGER,
        reps INTEGER,
        instructions TEXT,
        image_urls TEXT,
        FOREIGN KEY (workoutId) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        workoutName TEXT NOT NULL,
        durationMinutes INTEGER,
        caloriesBurned REAL,
        completedAt TEXT NOT NULL
      )
    ''');
  }

  // --- Workout History ---
  Future<void> insertWorkoutHistory({
    required int userId,
    required String workoutName,
    required int duration,
    required double calories,
  }) async {
    final db = await database;
    await db.insert('workout_history', {
      'userId': userId,
      'workoutName': workoutName,
      'durationMinutes': duration,
      'caloriesBurned': calories,
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getHistoryByUserId(int userId) async {
    final db = await database;
    return await db.query(
      'workout_history',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'completedAt DESC',
    );
  }

  // --- Workout CRUD ---
  Future<void> insertWorkout(Workout workout) async {
    final db = await database;
    await db.insert('workouts', workout.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Workout>> getWorkoutsByUserId(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('workouts', where: 'userId = ?', whereArgs: [userId]);
    return List.generate(maps.length, (i) => Workout.fromMap(maps[i]));
  }

  // Explicitly defined getAllWorkouts
  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('workouts');
    return List.generate(maps.length, (i) => Workout.fromMap(maps[i]));
  }

  Future<void> deleteWorkout(String id) async {
    final db = await database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
    await db.delete('workout_exercises', where: 'workoutId = ?', whereArgs: [id]);
  }

  // --- Exercise CRUD ---
  Future<void> insertExercise(Exercise exercise) async {
    final db = await database;
    final data = exercise.toMap();
    data['image_urls'] = jsonEncode(exercise.imageUrls);
    await db.insert('workout_exercises', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Exercise>> getExercisesForWorkout(String workoutId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('workout_exercises', where: 'workoutId = ?', whereArgs: [workoutId]);
    return List.generate(maps.length, (i) {
      var map = Map<String, dynamic>.from(maps[i]);
      map['image_urls'] = map['image_urls'] != null ? jsonDecode(map['image_urls']) : [];
      return Exercise.fromMap(map);
    });
  }

  Future<void> deleteAllExercisesForWorkout(String workoutId) async {
    final db = await database;
    await db.delete('workout_exercises', where: 'workoutId = ?', whereArgs: [workoutId]);
  }
}
