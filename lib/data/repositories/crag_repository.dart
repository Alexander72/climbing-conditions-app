import '../../domain/repositories/crag_repository_interface.dart';
import '../../domain/entities/crag.dart';
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

  /// Fetches full crag data (with children) for the bbox.
  /// Upserts all crags, upgrading any existing summary records to detailed.
  @override
  Future<void> refreshDetailedCragsByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final fetched = await _apiClient.fetchCragsDetailedByBBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );

      // Upsert: replaces summary records with full records (ConflictAlgorithm.replace in insertCrags)
      // User-added crags have a different source so they won't be overwritten in practice,
      // but if IDs collide the fetched version takes precedence here; user crags use
      // unique user-generated IDs so collisions won't occur in practice.
      if (fetched.isNotEmpty) {
        await _database.insertCrags(fetched);
      }
    } catch (_) {
      // Fail silently
    }
  }
}
