
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models/health_record_model.dart';

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
      'CREATE TABLE HealthRecords('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'heartRate INTEGER,'
          'waterIntake REAL,' // deimal point
          'weight REAL,'
          'createdOn DATETIME DEFAULT CURRENT_TIMESTAMP)'
    );
    log('Table Created');
  }

  // get all records
  Future<List<HealthRecordModel>> getRecords() async{
    final db = await _databaseService.database;
    var data = await db.query('HealthRecords', orderBy: 'createdOn DESC');
    List<HealthRecordModel> records = List.generate(
        data.length,
        (index) => HealthRecordModel.fromJson(data[index]),
    );
    log('Fetched ${records.length} records');
    return records;
  }

  // get today only record
  Future<List<HealthRecordModel>> getTodayRecords() async {
    final db = await _databaseService.database;
    // get in YYYY-MM-DD format
    String today = DateTime.now().toIso8601String().substring(0, 10);
    var data = await db.query(
      'HealthRecords',
      where: "createdOn LIKE ?",
      whereArgs: ['$today%'],
      orderBy: 'createdOn DESC',
    );
    List<HealthRecordModel> records = List.generate(
      data.length,
          (index) => HealthRecordModel.fromJson(data[index]),
    );
    log('Fetched ${records.length} records for today');
    return records;
  }

  // insert new record
  Future<void> insertRecord(HealthRecordModel record) async {
    final db = await _databaseService.database;
    var data = await db.rawInsert(
      'INSERT INTO HealthRecords(heartRate, waterIntake, weight) VALUES(?, ?, ?)',
      [record.heartRate, record.waterIntake, record.weight],
    );
    log('Inserted record id: $data');
  }

  // ipdate record
  Future<void> editRecord(HealthRecordModel record) async {
    final db = await _databaseService.database;
    var data = await db.update(
      'HealthRecords',
      record.toMap(),
      where: 'id=?',
      whereArgs: [record.id],
    );
    log('Updated $data record(s)');
  }

  // delete record
  Future<void> deleteRecord(int id) async {
    final db = await _databaseService.database;
    var data = await db.delete(
      'HealthRecords',
      where: 'id=?',
      whereArgs: [id],
    );
    log('Deleted $data record(s)');
  }
}