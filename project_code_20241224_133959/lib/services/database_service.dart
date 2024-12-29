import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'ecg_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE ecg_records(id INTEGER PRIMARY KEY AUTOINCREMENT, heart_rate INTEGER, timestamp TEXT)',
        );
      },
    );
  }

  Future<void> insertECGRecord(int heartRate) async {
    try {
      final db = await database;
      await db.insert(
        'ecg_records',
        {'heart_rate': heartRate, 'timestamp': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting ECG record: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getECGRecords() async {
    try {
      final db = await database;
      return await db.query('ecg_records');
    } catch (e) {
      print('Error retrieving ECG records: $e');
      return [];
    }
  }
} 