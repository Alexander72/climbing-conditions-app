import '../entities/crag.dart';
import '../entities/weather.dart';

abstract class CragRepositoryInterface {
  Future<List<Crag>> getAllCrags();
  Future<List<Crag>> getCragsBySource(String source);
  Future<Crag?> getCragById(String id);
  Future<void> addCrag(Crag crag);
  Future<void> deleteCrag(String id);
  Future<void> refreshSummaryCragsByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  });
  /// Returns [weatherPartial] from the API (`true` when some crags exceeded the cell cap).
  Future<bool> refreshDetailedCragsByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  });

  /// Fetches one crag + cell weather from `GET /api/crags/{id}` and upserts locally.
  Future<({Crag crag, Weather? weather})?> fetchCragDetailFromBackend(String id);
}
