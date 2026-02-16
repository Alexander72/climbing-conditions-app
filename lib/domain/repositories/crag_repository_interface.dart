import '../../domain/entities/crag.dart';

abstract class CragRepositoryInterface {
  Future<List<Crag>> getAllCrags();
  Future<List<Crag>> getCragsBySource(String source);
  Future<Crag?> getCragById(String id);
  Future<void> addCrag(Crag crag);
  Future<void> deleteCrag(String id);
  Future<void> refreshCrags({String? country, String? region});
}
