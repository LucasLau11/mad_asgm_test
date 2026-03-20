import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/heart_rate_model.dart';
import '../models/water_intake_model.dart';
import '../models/weight_model.dart';

class DatabaseService{
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();
  static Database? _database;

  // get database instance
  Future<Database> get database async{
    if(_database != null){
      return _database!;
    }
    _database = await initDatabase();
    return _database!;
  }

  // initialize dataabse
  Future<Database> initDatabase() async{
    final getDirectory = await getApplicationDocumentsDirectory();
    String path = '${getDirectory.path}/fitpulse.db';
    log(path);
    return await openDatabase(path, onCreate: _onCreate, version: 1);
  }

  // create table
  void _onCreate(Database db, int version) async{
    await db.execute(
        'CREATE TABLE WaterIntake('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'amountMl REAL,'
            'beverageType TEXT,'
            'time TEXT,'
            'note TEXT,'
            'createdOn DATETIME DEFAULT CURRENT_TIMESTAMP)'
    );
    log('Water Intake table created');

    await db.execute(
        'CREATE TABLE HeartRate('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'bpm INTEGER,'
            'status TEXT,'
            'note TEXT,'
            'createdOn DATETIME DEFAULT CURRENT_TIMESTAMP)'
    );
    log('Heart Rate table created');

    await db.execute(
        'CREATE TABLE Weight('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'weightKg REAL,'
            'note TEXT,'
            'createdOn DATETIME DEFAULT CURRENT_TIMESTAMP)'
    );
    log('Weight table created');
  }

  // ==========================================
  // WATER INTAKE
  // ==========================================

  Future<List<WaterIntakeModel>> getWaterRecords() async {
    final db = await database;
    var data = await db.query('WaterIntake', orderBy: 'createdOn DESC');
    return List.generate(data.length, (i) => WaterIntakeModel.fromJson(data[i]));
  }

  Future<List<WaterIntakeModel>> getTodayWaterRecords() async {
    final db = await database;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    var data = await db.query(
      'WaterIntake',
      where: 'createdOn LIKE ?',
      whereArgs: ['$today%'],
      orderBy: 'createdOn DESC',
    );
    return List.generate(data.length, (i) => WaterIntakeModel.fromJson(data[i]));
  }

  Future<void> insertWaterRecord(WaterIntakeModel record) async {
    final db = await database;
    var id = await db.rawInsert(
      'INSERT INTO WaterIntake(amountMl, beverageType, time, note) VALUES(?, ?, ?, ?)',
      [record.amountMl, record.beverageType, record.time, record.note],
    );
    log('Inserted water record id: $id');
  }

  Future<void> editWaterRecord(WaterIntakeModel record) async {
    final db = await database;
    var count = await db.update(
      'WaterIntake',
      record.toMap(),
      where: 'id=?',
      whereArgs: [record.id],
    );
    log('Updated $count water record(s)');
  }

  Future<void> deleteWaterRecord(int id) async {
    final db = await database;
    var count = await db.delete('WaterIntake', where: 'id=?', whereArgs: [id]);
    log('Deleted $count water record(s)');
  }

  // ==========================================
  // HEART RATE
  // ==========================================

  Future<List<HeartRateModel>> getHeartRateRecords() async {
    final db = await database;
    var data = await db.query('HeartRate', orderBy: 'createdOn DESC');
    return List.generate(data.length, (i) => HeartRateModel.fromJson(data[i]));
  }

  Future<List<HeartRateModel>> getTodayHeartRateRecords() async {
    final db = await database;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    var data = await db.query(
      'HeartRate',
      where: 'createdOn LIKE ?',
      whereArgs: ['$today%'],
      orderBy: 'createdOn DESC',
    );
    return List.generate(data.length, (i) => HeartRateModel.fromJson(data[i]));
  }

  Future<void> insertHeartRateRecord(HeartRateModel record) async {
    final db = await database;
    var id = await db.rawInsert(
      'INSERT INTO HeartRate(bpm, status, note) VALUES(?, ?, ?)',
      [record.bpm, record.status, record.note],
    );
    log('Inserted heart rate record id: $id');
  }

  Future<void> editHeartRateRecord(HeartRateModel record) async {
    final db = await database;
    var count = await db.update(
      'HeartRate',
      record.toMap(),
      where: 'id=?',
      whereArgs: [record.id],
    );
    log('Updated $count heart rate record(s)');
  }

  Future<void> deleteHeartRateRecord(int id) async {
    final db = await database;
    var count = await db.delete('HeartRate', where: 'id=?', whereArgs: [id]);
    log('Deleted $count heart rate record(s)');
  }

  // ==========================================
  // WEIGHT
  // ==========================================

  Future<List<WeightModel>> getWeightRecords() async {
    final db = await database;
    var data = await db.query('Weight', orderBy: 'createdOn DESC');
    return List.generate(data.length, (i) => WeightModel.fromJson(data[i]));
  }

  Future<List<WeightModel>> getTodayWeightRecords() async {
    final db = await database;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    var data = await db.query(
      'Weight',
      where: 'createdOn LIKE ?',
      whereArgs: ['$today%'],
      orderBy: 'createdOn DESC',
    );
    return List.generate(data.length, (i) => WeightModel.fromJson(data[i]));
  }

  Future<void> insertWeightRecord(WeightModel record) async {
    final db = await database;
    var id = await db.rawInsert(
      'INSERT INTO Weight(weightKg, note) VALUES(?, ?)',
      [record.weightKg, record.note],
    );
    log('Inserted weight record id: $id');
  }

  Future<void> editWeightRecord(WeightModel record) async {
    final db = await database;
    var count = await db.update(
      'Weight',
      record.toMap(),
      where: 'id=?',
      whereArgs: [record.id],
    );
    log('Updated $count weight record(s)');
  }

  Future<void> deleteWeightRecord(int id) async {
    final db = await database;
    var count = await db.delete('Weight', where: 'id=?', whereArgs: [id]);
    log('Deleted $count weight record(s)');
  }
}