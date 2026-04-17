import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/heart_rate_model/heart_rate_model.dart';
import '../../models/heart_rate_model/user_model.dart';
import '../../models/heart_rate_model/water_intake_model.dart';
import '../../models/heart_rate_model/weight_model.dart';



class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();
  static Database? _database;

  //who is currently logged in
  static UserModel? _currentUser;
  static UserModel? get currentUser => _currentUser;
  static int get currentUserId {
    assert(_currentUser != null, 'No user is logged in');
    return _currentUser!.id;
  }

  //Database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/fitpulse.db';
    log('DB path: $path');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  // Enable foreign-key support (SQLite is OFF by default)
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Create tables (newly installed)
  Future<void> _onCreate(Database db, int version) async {
    // Users
    await db.execute('''
      CREATE TABLE User (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        username     TEXT    NOT NULL UNIQUE,
        passwordHash TEXT    NOT NULL,
        email        TEXT,
        createdOn    DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    log('User table created');

    // Water Intake
    await db.execute('''
      CREATE TABLE WaterIntake (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id      INTEGER NOT NULL,
        amountMl     REAL,
        beverageType TEXT,
        time         TEXT,
        note         TEXT,
        createdOn    DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE
      )
    ''');
    log('WaterIntake table created');

    // Heart Rate
    await db.execute('''
      CREATE TABLE HeartRate (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id   INTEGER NOT NULL,
        bpm       INTEGER,
        status    TEXT,
        note      TEXT,
        createdOn DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE
      )
    ''');
    log('HeartRate table created');

    // Weight
    await db.execute('''
      CREATE TABLE Weight (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id   INTEGER NOT NULL,
        weightKg  REAL,
        note      TEXT,
        createdOn DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE
      )
    ''');
    log('Weight table created');
  }

  //Migrate existing DB (version 1 → 2)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      log('Migrating DB from v$oldVersion to v$newVersion');

      // Create User table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS User (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          username     TEXT    NOT NULL UNIQUE,
          passwordHash TEXT    NOT NULL,
          email        TEXT,
          createdOn    DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Insert a default "guest" account so existing rows keep working
      await db.execute('''
        INSERT OR IGNORE INTO User (id, username, passwordHash, email)
        VALUES (1, 'guest', '', '')
      ''');

      // Add user_id column to existing tables
      await db.execute(
          'ALTER TABLE WaterIntake ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          'ALTER TABLE HeartRate ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          'ALTER TABLE Weight ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');

      log('Migration to v2 complete');
    }
  }

  // Password hashing
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  //reset password
  Future<bool> resetPassword({
    required String username,
    required String newPassword,
  }) async {
    final db = await database;
    final count = await db.update(
      'User',
      {'passwordHash': _hashPassword(newPassword)},
      where: 'username = ?',
      whereArgs: [username.trim()],
    );
    return count > 0; // username not found
  }

  // authentication

  // Register a new user. Returns the created [UserModel] or null if the username is already taken.
  Future<UserModel?> registerUser({
    required String username,
    required String password,
    String email = '',
  }) async {
    final db = await database;
    try {
      final id = await db.insert('User', {
        'username': username.trim(),
        'passwordHash': _hashPassword(password),
        'email': email.trim(),
      });
      log('Registered user id: $id');
      final user = await _fetchUserById(id);
      _currentUser = user;
      return user;
    } catch (e) {
      // UNIQUE constraint violation → username taken
      log('registerUser error: $e');
      return null;
    }
  }

  // Login with username + password. Returns [UserModel] on success or null if credentials are wrong.
  Future<UserModel?> loginUser({
    required String username,
    required String password,
  }) async {
    final db = await database;
    final rows = await db.query(
      'User',
      where: 'username = ? AND passwordHash = ?',
      whereArgs: [username.trim(), _hashPassword(password)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = UserModel.fromJson(rows.first);
    _currentUser = user;
    log('Logged in as: ${user.username} (id ${user.id})');
    return user;
  }

  // Clear the current session.
  void logoutUser() {
    log('Logged out user: ${_currentUser?.username}');
    _currentUser = null;
  }

  Future<UserModel?> _fetchUserById(int id) async {
    final db = await database;
    final rows = await db.query('User', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return UserModel.fromJson(rows.first);
  }

  // WATER INTAKE
  Future<List<WaterIntakeModel>> getWaterRecords() async {
    final db = await database;
    final data = await db.query(
      'WaterIntake',
      where: 'user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'createdOn DESC',
    );
    return data.map((r) => WaterIntakeModel.fromJson(r)).toList();
  }

  Future<List<WaterIntakeModel>> getTodayWaterRecords() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await db.query(
      'WaterIntake',
      where: 'user_id = ? AND createdOn LIKE ?',
      whereArgs: [currentUserId, '$today%'],
      orderBy: 'createdOn DESC',
    );
    return data.map((r) => WaterIntakeModel.fromJson(r)).toList();
  }

  Future<void> insertWaterRecord(WaterIntakeModel record) async {
    final db = await database;
    final id = await db.rawInsert(
      'INSERT INTO WaterIntake(user_id, amountMl, beverageType, time, note) '
          'VALUES(?, ?, ?, ?, ?)',
      [currentUserId, record.amountMl, record.beverageType, record.time, record.note],
    );
    log('Inserted water record id: $id');
  }

  Future<void> editWaterRecord(WaterIntakeModel record) async {
    final db = await database;
    final count = await db.update(
      'WaterIntake',
      record.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [record.id, currentUserId],
    );
    log('Updated $count water record(s)');
  }

  Future<void> deleteWaterRecord(int id) async {
    final db = await database;
    final count = await db.delete(
      'WaterIntake',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, currentUserId],
    );
    log('Deleted $count water record(s)');
  }

  // HEART RATE
  Future<List<HeartRateModel>> getHeartRateRecords() async {
    final db = await database;
    final data = await db.query(
      'HeartRate',
      where: 'user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'createdOn DESC',
    );
    return data.map((r) => HeartRateModel.fromJson(r)).toList();
  }

  Future<List<HeartRateModel>> getTodayHeartRateRecords() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await db.query(
      'HeartRate',
      where: 'user_id = ? AND createdOn LIKE ?',
      whereArgs: [currentUserId, '$today%'],
      orderBy: 'createdOn DESC',
    );
    return data.map((r) => HeartRateModel.fromJson(r)).toList();
  }

  Future<void> insertHeartRateRecord(HeartRateModel record) async {
    final db = await database;
    final id = await db.rawInsert(
      'INSERT INTO HeartRate(user_id, bpm, status, note) VALUES(?, ?, ?, ?)',
      [currentUserId, record.bpm, record.status, record.note],
    );
    log('Inserted heart rate record id: $id');
  }

  Future<void> editHeartRateRecord(HeartRateModel record) async {
    final db = await database;
    final count = await db.update(
      'HeartRate',
      record.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [record.id, currentUserId],
    );
    log('Updated $count heart rate record(s)');
  }

  Future<void> deleteHeartRateRecord(int id) async {
    final db = await database;
    final count = await db.delete(
      'HeartRate',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, currentUserId],
    );
    log('Deleted $count heart rate record(s)');
  }

  // WEIGHT
  Future<List<WeightModel>> getWeightRecords() async {
    final db = await database;
    final data = await db.query(
      'Weight',
      where: 'user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'createdOn DESC',
    );
    return data.map((r) => WeightModel.fromJson(r)).toList();
  }

  Future<List<WeightModel>> getTodayWeightRecords() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await db.query(
      'Weight',
      where: 'user_id = ? AND createdOn LIKE ?',
      whereArgs: [currentUserId, '$today%'],
      orderBy: 'createdOn DESC',
    );
    return data.map((r) => WeightModel.fromJson(r)).toList();
  }

  Future<void> insertWeightRecord(WeightModel record) async {
    final db = await database;
    final id = await db.rawInsert(
      'INSERT INTO Weight(user_id, weightKg, note) VALUES(?, ?, ?)',
      [currentUserId, record.weightKg, record.note],
    );
    log('Inserted weight record id: $id');
  }

  Future<void> editWeightRecord(WeightModel record) async {
    final db = await database;
    final count = await db.update(
      'Weight',
      record.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [record.id, currentUserId],
    );
    log('Updated $count weight record(s)');
  }

  Future<void> deleteWeightRecord(int id) async {
    final db = await database;
    final count = await db.delete(
      'Weight',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, currentUserId],
    );
    log('Deleted $count weight record(s)');
  }
}
