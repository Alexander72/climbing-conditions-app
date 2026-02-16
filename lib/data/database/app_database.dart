import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/crag_model.dart';
import '../models/weather_model.dart';
import '../models/condition_model.dart';
import 'seed_data.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() => _instance;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'climbing_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    // Check if preloaded crags exist
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM crags WHERE source = ?', ['preloaded']),
    );
    
    if (count == 0) {
      // Load seed data if no preloaded crags exist
      final seedData = SeedData.getPreloadedCrags();
      final batch = db.batch();
      for (final crag in seedData) {
        batch.insert(
          'crags',
          crag.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Crags table
    await db.execute('''
      CREATE TABLE crags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        aspect TEXT NOT NULL,
        rockType TEXT NOT NULL,
        climbingTypes TEXT NOT NULL,
        elevation REAL,
        description TEXT,
        source TEXT NOT NULL
      )
    ''');

    // Weather cache table
    await db.execute('''
      CREATE TABLE weather_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        UNIQUE(latitude, longitude)
      )
    ''');

    // Condition history table
    await db.execute('''
      CREATE TABLE condition_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        crag_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        recommendation TEXT NOT NULL,
        factors TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (crag_id) REFERENCES crags(id)
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_crags_source ON crags(source)');
    await db.execute('CREATE INDEX idx_weather_cache_location ON weather_cache(latitude, longitude)');
    await db.execute('CREATE INDEX idx_condition_history_crag ON condition_history(crag_id)');
  }

  // Crags CRUD
  Future<void> insertCrag(CragModel crag) async {
    final db = await database;
    await db.insert(
      'crags',
      crag.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCrags(List<CragModel> crags) async {
    final db = await database;
    final batch = db.batch();
    for (final crag in crags) {
      batch.insert(
        'crags',
        crag.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CragModel>> getAllCrags() async {
    final db = await database;
    final maps = await db.query('crags');
    return maps.map((map) => CragModel.fromJson(map)).toList();
  }

  Future<List<CragModel>> getCragsBySource(String source) async {
    final db = await database;
    final maps = await db.query(
      'crags',
      where: 'source = ?',
      whereArgs: [source],
    );
    return maps.map((map) => CragModel.fromJson(map)).toList();
  }

  Future<CragModel?> getCragById(String id) async {
    final db = await database;
    final maps = await db.query(
      'crags',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CragModel.fromJson(maps.first);
  }

  Future<void> deleteCrag(String id) async {
    final db = await database;
    await db.delete('crags', where: 'id = ?', whereArgs: [id]);
  }

  // Weather cache
  Future<void> cacheWeather({
    required double latitude,
    required double longitude,
    required WeatherModel weather,
  }) async {
    final db = await database;
    final json = weather.toJson();
    await db.insert(
      'weather_cache',
      {
        'latitude': latitude,
        'longitude': longitude,
        'data': jsonEncode(json),
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WeatherModel?> getCachedWeather({
    required double latitude,
    required double longitude,
    required int maxAgeSeconds,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final maps = await db.query(
      'weather_cache',
      where: 'latitude = ? AND longitude = ? AND timestamp > ?',
      whereArgs: [latitude, longitude, now - maxAgeSeconds],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final data = maps.first['data'] as String;
    return WeatherModel.fromJson(jsonDecode(data));
  }

  // Condition history
  Future<void> saveConditionHistory({
    required String cragId,
    required ConditionModel condition,
  }) async {
    final db = await database;
    await db.insert(
      'condition_history',
      {
        'crag_id': cragId,
        'score': condition.score,
        'recommendation': condition.recommendationString,
        'factors': jsonEncode(condition.factors),
        'timestamp': condition.lastUpdated,
      },
    );
  }

  Future<List<ConditionModel>> getConditionHistory(String cragId) async {
    final db = await database;
    final maps = await db.query(
      'condition_history',
      where: 'crag_id = ?',
      whereArgs: [cragId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) {
      return ConditionModel(
        score: map['score'] as int,
        recommendationString: map['recommendation'] as String,
        factors: List<String>.from(jsonDecode(map['factors'] as String)),
        lastUpdated: map['timestamp'] as int,
      );
    }).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
