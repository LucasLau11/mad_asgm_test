import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/workout_model.dart';
import '../models/workout_exercise_model.dart';

class WorkoutDatabaseService {
  static final WorkoutDatabaseService _instance = WorkoutDatabaseService._internal();
  static Database? _database;

  factory WorkoutDatabaseService() {
    return _instance;
  }

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
      version: 2, // Bumped version to add userId
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
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
      CREATE TABLE workout_exercises (
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add userId column to existing workouts table
      await db.execute('ALTER TABLE workouts ADD COLUMN userId INTEGER DEFAULT 0');
    }
  }

  // --- Workout CRUD (Updated with userId) ---

  Future<void> insertWorkout(Workout workout) async {
    final db = await database;
    await db.insert(
      'workouts',
      workout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Workout>> getWorkoutsByUserId(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workouts',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => Workout.fromMap(maps[i]));
  }

  // Still keep getAllWorkouts for admin/debug if needed, 
  // but most pages will use getWorkoutsByUserId
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

    await db.insert(
      'workout_exercises',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getExercisesForWorkout(String workoutId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workout_exercises',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );

    return List.generate(maps.length, (i) {
      var map = Map<String, dynamic>.from(maps[i]);
      if (map['image_urls'] != null) {
        map['image_urls'] = jsonDecode(map['image_urls']);
      } else {
        map['image_urls'] = [];
      }
      return Exercise.fromMap(map);
    });
  }

  Future<void> deleteAllExercisesForWorkout(String workoutId) async {
    final db = await database;
    await db.delete('workout_exercises', where: 'workoutId = ?', whereArgs: [workoutId]);
  }
}
