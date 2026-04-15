import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../models/crag_model.dart';
import '../../core/config.dart';
import '../../domain/entities/aspect.dart';
import '../../domain/entities/rock_type.dart';
import '../../domain/entities/climbing_type.dart';
import '../../domain/entities/crag_source.dart';

/// Parses merged One Call + `historical` JSON (same shape as `GET /api/weather`).
WeatherModel parseMergedWeatherJson(Map<String, dynamic> json) {
  final current = json['current'] as Map<String, dynamic>;
  final currentWeather = CurrentWeatherModel(
    temp: (current['temp'] as num).toDouble(),
    humidity: (current['humidity'] as num).toDouble(),
    rain: current['rain']?['1h'] as double?,
    windSpeed: (current['wind_speed'] as num).toDouble(),
    dt: current['dt'] as int,
  );

  final historical = <HistoricalWeatherModel>[];
  if (json['historical'] is List) {
    for (final item in json['historical'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;
      final rainRaw = itemMap['rain'];
      historical.add(HistoricalWeatherModel(
        dt: itemMap['dt'] as int,
        temp: (itemMap['temp'] as num).toDouble(),
        rain: rainRaw == null ? null : (rainRaw as num).toDouble(),
      ));
    }
  } else if (json['hourly'] != null) {
    final hourly = json['hourly'] as List<dynamic>;
    final now = DateTime.now();
    final fiveDaysAgo = now.subtract(const Duration(days: 5));

    for (final item in hourly) {
      final itemMap = item as Map<String, dynamic>;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (itemMap['dt'] as int) * 1000,
      );
      if (dt.isAfter(fiveDaysAgo) && dt.isBefore(now)) {
        historical.add(HistoricalWeatherModel(
          dt: itemMap['dt'] as int,
          temp: (itemMap['temp'] as num).toDouble(),
          rain: itemMap['rain']?['1h'] as double?,
        ));
      }
    }
  }

  final forecast = <ForecastWeatherModel>[];
  if (json['hourly'] != null) {
    final hourly = json['hourly'] as List<dynamic>;
    final now = DateTime.now();
    final twoDaysLater = now.add(const Duration(days: 2));

    for (final item in hourly) {
      final itemMap = item as Map<String, dynamic>;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (itemMap['dt'] as int) * 1000,
      );
      if (dt.isAfter(now) && dt.isBefore(twoDaysLater)) {
        forecast.add(ForecastWeatherModel(
          dt: itemMap['dt'] as int,
          temp: (itemMap['temp'] as num).toDouble(),
          rain: itemMap['rain']?['1h'] as double?,
          windSpeed: (itemMap['wind_speed'] as num).toDouble(),
        ));
      }
    }
  }

  return WeatherModel(
    current: currentWeather,
    historical: historical,
    forecast: forecast,
  );
}

/// Builds [CragModel] from backend catalog JSON (`GET /api/crags`, `GET /api/crags/{id}`).
///
/// Catalog DTOs omit `aspect`, `rockType`, `climbingTypes`, and `source`; the app uses
/// the same defaults as bbox list parsing so detail responses parse like list rows.
CragModel _cragModelFromBackendCatalogMap(
  Map<String, dynamic> m, {
  bool defaultSummaryOnly = false,
}) {
  final lat = m['latitude'];
  final lng = m['longitude'];
  if (lat == null || lng == null) {
    throw const FormatException('Crag missing latitude/longitude');
  }

  final summaryFlag = m['isSummaryOnly'] as bool? ?? defaultSummaryOnly;

  List<GradeHistogramBinModel>? gradeBins;
  final gradeRaw = m['gradeHistogram'];
  if (gradeRaw is List<dynamic>) {
    gradeBins = gradeRaw
        .map(
          (e) => GradeHistogramBinModel.fromJson(
            Map<String, dynamic>.from(e as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  List<String>? factors;
  final fRaw = m['conditionFactors'];
  if (fRaw is List<dynamic>) {
    factors = fRaw.map((e) => e.toString()).toList();
  }

  final idRaw = m['id'];
  final id = idRaw == null ? 'unknown' : idRaw.toString();

  return CragModel(
    id: id,
    name: m['name'] as String? ?? 'Unknown Crag',
    latitude: (lat as num).toDouble(),
    longitude: (lng as num).toDouble(),
    aspectString: Aspect.unknown.name,
    rockTypeString: RockType.limestone.name,
    climbingTypesString: [ClimbingType.sport.name],
    sourceString: CragSource.fetched.name,
    isSummaryOnly: summaryFlag,
    elevation: (m['elevation'] as num?)?.toDouble(),
    description: m['description'] as String?,
    routeCount: (m['routeCount'] as num?)?.toInt(),
    sportCount: (m['sportCount'] as num?)?.toInt(),
    tradNPCount: (m['tradNPCount'] as num?)?.toInt(),
    boulderCount: (m['boulderCount'] as num?)?.toInt(),
    dwsCount: (m['dwsCount'] as num?)?.toInt(),
    gradeHistogram: gradeBins,
    weatherCellId: m['weatherCellId'] as String?,
    conditionScore: (m['conditionScore'] as num?)?.toInt(),
    conditionRecommendation: m['conditionRecommendation'] as String?,
    conditionFactors: factors,
    conditionLastUpdated: (m['conditionLastUpdated'] as num?)?.toInt(),
    weatherAsOf: m['weatherAsOf'] as String?,
  );
}

/// Single-crag API payload (`GET /api/crags/{id}`).
class CragDetailApiResult {
  final CragModel crag;
  final Map<String, dynamic> weatherCells;
  final bool weatherPartial;

  const CragDetailApiResult({
    required this.crag,
    required this.weatherCells,
    required this.weatherPartial,
  });
}

/// Single HTTP client that proxies external API calls through the backend (weather).
/// Crag locations are served from the backend’s local catalog (`GET /api/crags`).
class BackendApiClient {
  final http.Client _client;
  final String _baseUrl;

  BackendApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.backendBaseUrl;

  // ---------------------------------------------------------------------------
  // Weather
  // ---------------------------------------------------------------------------

  Future<WeatherModel> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/weather').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    );

    developer.log(
      'Fetching weather from backend: $uri',
      name: 'BackendApiClient',
    );

    try {
      final response = await _client.get(uri);

      developer.log(
        'Backend weather response: ${response.statusCode}',
        name: 'BackendApiClient',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return parseMergedWeatherJson(jsonData);
      } else {
        throw Exception(
          'Failed to fetch weather from backend: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching weather data: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Crags
  // ---------------------------------------------------------------------------

  /// Fetches crag names + coordinates only for the given viewport bbox.
  /// Used at zoom 7–9 (summary tier). Children are not included.
  Future<List<CragModel>> fetchCragsSummaryByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final jsonData = await _getCragsJson(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      detailLevel: 'summary',
    );
    return _parseCragsResponse(jsonData, isSummaryOnly: true);
  }

  /// Fetches crags with route stats, optional per-crag conditions, and `weatherCells`.
  Future<({List<CragModel> crags, bool weatherPartial})> fetchCragsDetailedByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final jsonData = await _getCragsJson(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      detailLevel: 'full',
    );
    final partial = jsonData['weatherPartial'] as bool? ?? false;
    final crags = _parseCragsResponse(jsonData, isSummaryOnly: false);
    return (crags: crags, weatherPartial: partial);
  }

  /// One crag plus `weatherCells` for its cell (path may contain `:`).
  Future<CragDetailApiResult> getCragById(String cragId) async {
    final encoded = Uri.encodeComponent(cragId);
    final uri = Uri.parse('$_baseUrl/api/crags/$encoded');
    developer.log(
      'Fetching crag detail from backend: $uri',
      name: 'BackendApiClient',
    );
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 404) {
        throw Exception('Crag not found');
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch crag: ${response.statusCode} - ${response.body}',
        );
      }
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final cragMap = jsonData['crag'] as Map<String, dynamic>;
      final crag = _cragModelFromBackendCatalogMap(cragMap);
      final cellsRaw = jsonData['weatherCells'];
      final cells = <String, dynamic>{};
      if (cellsRaw is Map<String, dynamic>) {
        cells.addAll(cellsRaw);
      } else if (cellsRaw is Map) {
        cellsRaw.forEach((k, v) {
          cells[k.toString()] = v;
        });
      }
      final partial = jsonData['weatherPartial'] as bool? ?? false;
      return CragDetailApiResult(
        crag: crag,
        weatherCells: cells,
        weatherPartial: partial,
      );
    } catch (e, st) {
      developer.log(
        'getCragById failed cragId=$cragId',
        name: 'BackendApiClient',
        error: e,
        stackTrace: st,
      );
      debugPrint('[BackendApiClient] getCragById FAILED id=$cragId: $e\n$st');
      throw Exception('Error fetching crag detail: $e');
    }
  }

  Future<Map<String, dynamic>> _getCragsJson({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required String detailLevel,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/crags').replace(
      queryParameters: {
        'min_lat': minLat.toString(),
        'max_lat': maxLat.toString(),
        'min_lng': minLng.toString(),
        'max_lng': maxLng.toString(),
        'detail_level': detailLevel,
      },
    );

    developer.log(
      'Fetching crags [$detailLevel] from backend: $uri',
      name: 'BackendApiClient',
    );

    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch crags from backend: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching crags: $e');
    }
  }

  List<CragModel> _parseCragsResponse(
    Map<String, dynamic> json, {
    bool isSummaryOnly = false,
  }) {
    final crags = <CragModel>[];
    final rawList = json['crags'] as List<dynamic>?;
    if (rawList == null) return crags;

    for (final item in rawList) {
      final m = item as Map<String, dynamic>;
      try {
        crags.add(
          _cragModelFromBackendCatalogMap(
            m,
            defaultSummaryOnly: isSummaryOnly,
          ),
        );
      } on FormatException {
        continue;
      }
    }

    return crags;
  }
}
