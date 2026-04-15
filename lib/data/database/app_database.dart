import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/crag_model.dart';
import '../models/weather_model.dart';
import '../models/condition_model.dart';

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
    // On web, getDatabasesPath() is null; use a simple name (stored in IndexedDB).
    // On desktop/mobile, use the normal documents path.
    final String path;
    if (kIsWeb) {
      path = 'climbing_app.db';
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'climbing_app.db');
    }

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Removes null values, JSON-encodes [List] values, and stores [bool] as 0/1.
  ///
  /// sqflite_common_ffi_web only accepts num, String, and Uint8List for insert
  /// arguments (no bool, no List, no null in the map).
  static Map<String, Object> _sanitizeMap(Map<String, dynamic> map) {
    return Map.fromEntries(
      map.entries.where((e) => e.value != null).map((e) {
        final v = e.value;
        final Object serialized;
        if (v is List) {
          serialized = jsonEncode(v);
        } else if (v is bool) {
          serialized = v ? 1 : 0;
        } else {
          serialized = v as Object;
        }
        return MapEntry(e.key, serialized);
      }),
    );
  }

  static bool _boolFromSqlColumn(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    return false;
  }

  /// Decodes JSON-encoded list columns back to Dart lists so that
  /// CragModel.fromJson receives the expected types.
  static Map<String, dynamic> _deserializeCragMap(Map<String, dynamic> map) {
    return {
      ...map,
      'climbingTypes': map['climbingTypes'] is String
          ? jsonDecode(map['climbingTypes'] as String)
          : map['climbingTypes'],
      'conditionFactors': map['conditionFactors'] == null
          ? null
          : (map['conditionFactors'] is String
              ? List<String>.from(
                  jsonDecode(map['conditionFactors'] as String) as List<dynamic>,
                )
              : map['conditionFactors']),
      'isSummaryOnly': _boolFromSqlColumn(map['isSummaryOnly']),
    };
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE crags ADD COLUMN isSummaryOnly INTEGER NOT NULL DEFAULT 0',
      );
      // Remove any pre-loaded seed crags from old installations
      await db.delete('crags', where: 'source = ?', whereArgs: ['preloaded']);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE crags ADD COLUMN routeCount INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN sportCount INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN tradNPCount INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN boulderCount INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN dwsCount INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN gradeHistogram TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE crags ADD COLUMN weatherCellId TEXT');
      await db.execute('ALTER TABLE crags ADD COLUMN conditionScore INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN conditionRecommendation TEXT');
      await db.execute('ALTER TABLE crags ADD COLUMN conditionFactors TEXT');
      await db.execute('ALTER TABLE crags ADD COLUMN conditionLastUpdated INTEGER');
      await db.execute('ALTER TABLE crags ADD COLUMN weatherAsOf TEXT');
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
        source TEXT NOT NULL,
        isSummaryOnly INTEGER NOT NULL DEFAULT 0,
        routeCount INTEGER,
        sportCount INTEGER,
        tradNPCount INTEGER,
        boulderCount INTEGER,
        dwsCount INTEGER,
        gradeHistogram TEXT,
        weatherCellId TEXT,
        conditionScore INTEGER,
        conditionRecommendation TEXT,
        conditionFactors TEXT,
        conditionLastUpdated INTEGER,
        weatherAsOf TEXT
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
      _sanitizeMap(crag.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCrags(List<CragModel> crags) async {
    final db = await database;
    final batch = db.batch();
    for (final crag in crags) {
      batch.insert(
        'crags',
        _sanitizeMap(crag.toJson()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CragModel>> getAllCrags() async {
    final db = await database;
    final maps = await db.query('crags');
    return maps.map((map) => CragModel.fromJson(_deserializeCragMap(map))).toList();
  }

  Future<List<CragModel>> getCragsBySource(String source) async {
    final db = await database;
    final maps = await db.query(
      'crags',
      where: 'source = ?',
      whereArgs: [source],
    );
    return maps.map((map) => CragModel.fromJson(_deserializeCragMap(map))).toList();
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
    return CragModel.fromJson(_deserializeCragMap(maps.first));
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
