import 'package:flutter/foundation.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/crag_source.dart';
import '../../data/repositories/crag_repository.dart';

class CragProvider with ChangeNotifier {
  final CragRepository _repository;
  List<Crag> _crags = [];
  bool _isLoading = false;
  String? _error;

  CragProvider({CragRepository? repository})
      : _repository = repository ?? CragRepository();

  List<Crag> get crags => _crags;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Database initialization will load seed data automatically
      // Just load all crags (preloaded + fetched)
      await loadCrags();
    } catch (e, stackTrace) {
      _error = 'Failed to initialize crags: $e';
      debugPrint('[CragProvider] initialize() failed\n  Error: $e\n  Cause: ${e.runtimeType}\n  StackTrace:\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCrags() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _crags = await _repository.getAllCrags();
    } catch (e, stackTrace) {
      _error = 'Failed to load crags: $e';
      debugPrint('[CragProvider] loadCrags() failed\n  Error: $e\n  Cause: ${e.runtimeType}\n  StackTrace:\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCrags({String? country, String? region}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.refreshCrags(country: country, region: region);
      await loadCrags();
    } catch (e, stackTrace) {
      _error = 'Failed to refresh crags: $e';
      debugPrint('[CragProvider] refreshCrags() failed\n  Error: $e\n  Cause: ${e.runtimeType}\n  StackTrace:\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCrag(Crag crag) async {
    try {
      await _repository.addCrag(crag);
      await loadCrags();
    } catch (e, stackTrace) {
      _error = 'Failed to add crag: $e';
      debugPrint('[CragProvider] addCrag() failed for crag id=${crag.id}\n  Error: $e\n  Cause: ${e.runtimeType}\n  StackTrace:\n$stackTrace');
      notifyListeners();
    }
  }

  Future<void> deleteCrag(String id) async {
    try {
      await _repository.deleteCrag(id);
      await loadCrags();
    } catch (e, stackTrace) {
      _error = 'Failed to delete crag: $e';
      debugPrint('[CragProvider] deleteCrag() failed for id=$id\n  Error: $e\n  Cause: ${e.runtimeType}\n  StackTrace:\n$stackTrace');
      notifyListeners();
    }
  }

  List<Crag> getCragsBySource(CragSource source) {
    return _crags.where((c) => c.source == source).toList();
  }

  Crag? getCragById(String id) {
    try {
      return _crags.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}
