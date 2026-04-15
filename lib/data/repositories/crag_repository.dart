import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../domain/repositories/crag_repository_interface.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/weather.dart';
import '../datasources/backend_api_client.dart';
import '../database/app_database.dart';
import '../models/crag_model.dart';

class CragRepository implements CragRepositoryInterface {
  final BackendApiClient _apiClient;
  final AppDatabase _database;

  CragRepository({
    BackendApiClient? apiClient,
    AppDatabase? database,
  })  : _apiClient = apiClient ?? BackendApiClient(),
        _database = database ?? AppDatabase();

  @override
  Future<List<Crag>> getAllCrags() async {
    final models = await _database.getAllCrags();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Crag>> getCragsBySource(String source) async {
    final models = await _database.getCragsBySource(source);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Crag?> getCragById(String id) async {
    final model = await _database.getCragById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addCrag(Crag crag) async {
    final model = CragModel.fromEntity(crag);
    await _database.insertCrag(model);
  }

  @override
  Future<void> deleteCrag(String id) async {
    await _database.deleteCrag(id);
  }

  /// Fetches crag presence (name + coords only) for the bbox.
  /// New crags are inserted with isSummaryOnly=true.
  /// Existing crags (user-added or already detailed) are not overwritten.
  @override
  Future<void> refreshSummaryCragsByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final fetched = await _apiClient.fetchCragsSummaryByBBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );

      final existingModels = await _database.getAllCrags();
      final existingIds = existingModels.map((c) => c.id).toSet();

      final newCrags = fetched.where((c) => !existingIds.contains(c.id)).toList();
      if (newCrags.isNotEmpty) {
        await _database.insertCrags(newCrags);
      }
    } catch (_) {
      // Fail silently — app still works with previously cached crags
    }
  }

  /// Fetches detailed crag rows for the bbox (`isSummaryOnly: false` from the API).
  /// Upserts all crags, upgrading any existing summary records to detailed.
  @override
  Future<bool> refreshDetailedCragsByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final result = await _apiClient.fetchCragsDetailedByBBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );

      // Upsert: replaces summary records with full records (ConflictAlgorithm.replace in insertCrags)
      // User-added crags have a different source so they won't be overwritten in practice,
      // but if IDs collide the fetched version takes precedence here; user crags use
      // unique user-generated IDs so collisions won't occur in practice.
      if (result.crags.isNotEmpty) {
        await _database.insertCrags(result.crags);
      }
      return result.weatherPartial;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<({Crag crag, Weather? weather})?> fetchCragDetailFromBackend(String id) async {
    var phase = 'init';
    try {
      developer.log('fetchCragDetailFromBackend start id=$id', name: 'CragRepository');

      phase = 'getCragById';
      final r = await _apiClient.getCragById(id);
      developer.log(
        'after getCragById: weatherCellId=${r.crag.weatherCellId} '
        'weatherCellKeys=[${r.weatherCells.keys.join(", ")}]',
        name: 'CragRepository',
      );

      phase = 'insertCrag';
      await _database.insertCrag(r.crag);
      developer.log('after insertCrag', name: 'CragRepository');

      phase = 'toEntity';
      final entity = r.crag.toEntity();
      Weather? w;
      final wid = r.crag.weatherCellId;
      if (wid != null && r.weatherCells.containsKey(wid)) {
        final raw = r.weatherCells[wid];
        if (raw is Map) {
          phase = 'parseMergedWeatherJson($wid)';
          w = parseMergedWeatherJson(
            Map<String, dynamic>.from(raw),
          ).toEntity();
          developer.log('after parseMergedWeatherJson', name: 'CragRepository');
        } else {
          developer.log(
            'weatherCells[$wid] skipped: expected Map, got ${raw.runtimeType}',
            name: 'CragRepository',
          );
        }
      } else {
        developer.log(
          'no weather cell payload (weatherCellId=$wid '
          'hasKey=${wid != null && r.weatherCells.containsKey(wid)})',
          name: 'CragRepository',
        );
      }
      return (crag: entity, weather: w);
    } catch (e, st) {
      developer.log(
        'fetchCragDetailFromBackend failed at $phase id=$id',
        name: 'CragRepository',
        error: e,
        stackTrace: st,
      );
      debugPrint('[CragRepository] FAILED at $phase id=$id: $e\n$st');
      return null;
    }
  }
}
