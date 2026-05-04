import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/config.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/weather.dart';
import '../../domain/entities/crag_source.dart';
import '../../data/repositories/crag_repository.dart';

class CragProvider with ChangeNotifier {
  final CragRepository _repository;
  List<Crag> _crags = [];
  bool _isLoading = false;
  String? _error;

  // Viewport state
  LatLngBounds? _viewportBounds;
  double _currentZoom = AppConfig.defaultMapZoom;
  bool _isFetchingViewport = false;
  Timer? _debounceTimer;

  // Separate bbox key caches for each tier so zooming in always triggers a
  // detail fetch even when the summary tile was already loaded.
  final Set<String> _summaryBBoxKeys = {};
  final Set<String> _detailedBBoxKeys = {};

  /// Last `weatherPartial` from a detailed bbox fetch (API cell cap).
  bool _viewportWeatherPartial = false;
  DateTime _selectedConditionDate = _todayUtc();

  CragProvider({CragRepository? repository})
      : _repository = repository ?? CragRepository();

  List<Crag> get crags => _crags;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isFetchingViewport => _isFetchingViewport;

  /// True when the current zoom is in the detailed tier (> 9).
  bool get isDetailedZoom => _currentZoom > 9.0;

  /// Current zoom level — exposed so the list screen can read it.
  double get currentZoom => _currentZoom;

  bool get viewportWeatherPartial => _viewportWeatherPartial;
  DateTime get selectedConditionDate => _selectedConditionDate;

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static DateTime _maxSelectableUtc() => _todayUtc().add(const Duration(days: 13));

  DateTime clampConditionDate(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    final minDate = _todayUtc();
    final maxDate = _maxSelectableUtc();
    if (normalized.isBefore(minDate)) return minDate;
    if (normalized.isAfter(maxDate)) return maxDate;
    return normalized;
  }

  /// Crags filtered to the current viewport.
  /// - zoom < 7  → empty list (nothing shown)
  /// - zoom 7–9  → summary crags within viewport
  /// - zoom > 9  → all crags within viewport (summary + detailed)
  List<Crag> get visibleCrags {
    if (_currentZoom < 7.0) return [];
    final bounds = _viewportBounds;
    if (bounds == null) return _crags;
    return _crags.where((c) {
      return c.latitude >= bounds.south &&
          c.latitude <= bounds.north &&
          c.longitude >= bounds.west &&
          c.longitude <= bounds.east;
    }).toList();
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadCrags();
    } catch (e) {
      _error = 'Failed to initialize crags: $e';
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
    } catch (e) {
      _error = 'Failed to load crags: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCrag(Crag crag) async {
    try {
      await _repository.addCrag(crag);
      await loadCrags();
    } catch (e) {
      _error = 'Failed to add crag: $e';
      notifyListeners();
    }
  }

  Future<void> deleteCrag(String id) async {
    try {
      await _repository.deleteCrag(id);
      await loadCrags();
    } catch (e) {
      _error = 'Failed to delete crag: $e';
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

  /// Called by the map on every MoveEnd / ZoomEnd event.
  /// Instantly updates [visibleCrags] then debounces a backend fetch.
  void updateViewport(LatLngBounds bounds, double zoom) {
    _viewportBounds = bounds;
    _currentZoom = zoom;
    notifyListeners(); // instant filter update

    _debounceTimer?.cancel();
    if (zoom < 7.0) return;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchForViewport(bounds, zoom);
    });
  }

  Future<void> _fetchForViewport(LatLngBounds bounds, double zoom) async {
    final minLat = bounds.south;
    final maxLat = bounds.north;
    final minLng = bounds.west;
    final maxLng = bounds.east;

    // Round to 1 decimal (≈11 km) to suppress refetch on micro-pans
    final key =
        '${minLat.toStringAsFixed(1)}_${maxLat.toStringAsFixed(1)}_'
        '${minLng.toStringAsFixed(1)}_${maxLng.toStringAsFixed(1)}';

    final isDetailed = zoom > 9.0;
    final cache = isDetailed ? _detailedBBoxKeys : _summaryBBoxKeys;

    if (cache.contains(key)) return;

    _isFetchingViewport = true;
    notifyListeners();

    try {
      if (isDetailed) {
        _viewportWeatherPartial = await _repository.refreshDetailedCragsByBBox(
          minLat: minLat,
          maxLat: maxLat,
          minLng: minLng,
          maxLng: maxLng,
        );
      } else {
        _viewportWeatherPartial = false;
        await _repository.refreshSummaryCragsByBBox(
          minLat: minLat,
          maxLat: maxLat,
          minLng: minLng,
          maxLng: maxLng,
        );
      }
      cache.add(key);
      _crags = await _repository.getAllCrags();
    } catch (e, st) {
      developer.log(
        'Viewport crag fetch failed: $e',
        name: 'CragProvider',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isFetchingViewport = false;
      notifyListeners();
    }
  }

  /// Loads one crag from `GET /api/crags/{id}` and persists; returns merged weather when present.
  Future<({Crag crag, Weather? weather})?> loadCragDetailFromBackend(String id) {
    return _repository.fetchCragDetailFromBackend(id);
  }

  void setSelectedConditionDate(DateTime date) {
    final normalized = clampConditionDate(date);
    if (_selectedConditionDate == normalized) return;
    _selectedConditionDate = normalized;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
