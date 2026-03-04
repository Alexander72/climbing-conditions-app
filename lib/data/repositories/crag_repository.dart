import '../../domain/repositories/crag_repository_interface.dart';
import '../../domain/entities/crag.dart';
import '../datasources/backend_api_client.dart';
import '../database/app_database.dart';
import '../models/crag_model.dart';

class CragRepository implements CragRepositoryInterface {
  final BackendApiClient _apiClient;
  final AppDatabase _database;
  bool _hasLoadedFetchedCrags = false;

  CragRepository({
    BackendApiClient? apiClient,
    AppDatabase? database,
  })  : _apiClient = apiClient ?? BackendApiClient(),
        _database = database ?? AppDatabase();

  @override
  Future<List<Crag>> getAllCrags() async {
    // Ensure fetched crags are loaded
    if (!_hasLoadedFetchedCrags) {
      await refreshCrags();
    }

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

  static const String _defaultCountry = 'Belgium';

  @override
  Future<void> refreshCrags({String? country, String? region}) async {
    try {
      // Fetch crags from OpenBeta (default to Belgium when not specified)
      final fetchedCrags = await _apiClient.fetchCragsByRegion(
        country: country ?? _defaultCountry,
        region: region,
      );

      // Merge with existing crags (preloaded + user-added are preserved)
      // Only update fetched crags
      final existingCrags = await _database.getAllCrags();
      final existingIds = existingCrags.map((c) => c.id).toSet();

      // Filter out crags that already exist (to preserve preloaded/user data)
      final newCrags = fetchedCrags
          .where((c) => !existingIds.contains(c.id))
          .toList();

      if (newCrags.isNotEmpty) {
        await _database.insertCrags(newCrags);
      }

      _hasLoadedFetchedCrags = true;
    } catch (e) {
      // Log error but don't fail - we can still use preloaded crags
      // Error is handled silently to allow app to work with preloaded crags only
    }
  }
}
