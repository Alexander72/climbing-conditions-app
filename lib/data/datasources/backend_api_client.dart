import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../models/crag_model.dart';
import '../../core/config.dart';
import '../../domain/entities/aspect.dart';
import '../../domain/entities/rock_type.dart';
import '../../domain/entities/climbing_type.dart';
import '../../domain/entities/crag_source.dart';

/// Single HTTP client that proxies all external API calls through the backend.
/// Replaces both [WeatherApiClient] and [OpenBetaApiClient].
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
        return _parseWeatherResponse(jsonData);
      } else {
        throw Exception(
          'Failed to fetch weather from backend: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching weather data: $e');
    }
  }

  WeatherModel _parseWeatherResponse(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final currentWeather = CurrentWeatherModel(
      temp: (current['temp'] as num).toDouble(),
      humidity: (current['humidity'] as num).toDouble(),
      rain: current['rain']?['1h'] as double?,
      windSpeed: (current['wind_speed'] as num).toDouble(),
      dt: current['dt'] as int,
    );

    final historical = <HistoricalWeatherModel>[];
    if (json['hourly'] != null) {
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
    return _fetchCragsByBBox(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      detailLevel: 'summary',
      isSummaryOnly: true,
    );
  }

  /// Fetches crags with children for the given viewport bbox.
  /// Used at zoom > 9 (detailed tier).
  Future<List<CragModel>> fetchCragsDetailedByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    return _fetchCragsByBBox(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      detailLevel: 'full',
      isSummaryOnly: false,
    );
  }

  Future<List<CragModel>> _fetchCragsByBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required String detailLevel,
    required bool isSummaryOnly,
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
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return _parseCragsResponse(jsonData, isSummaryOnly: isSummaryOnly);
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

    final dataNode = json['data'];
    final rawList = dataNode != null
        ? (dataNode['cragsWithin'] ?? dataNode['areas'])
        : null;
    if (rawList != null) {
      final areas = rawList as List<dynamic>;

      for (final area in areas) {
        final areaMap = area as Map<String, dynamic>;
        final metadata = areaMap['metadata'] as Map<String, dynamic>?;

        if (metadata != null &&
            metadata['lat'] != null &&
            metadata['lng'] != null) {
          crags.add(CragModel(
            id: areaMap['area_name'] ?? 'unknown',
            name: areaMap['area_name'] ?? 'Unknown Crag',
            latitude: (metadata['lat'] as num).toDouble(),
            longitude: (metadata['lng'] as num).toDouble(),
            aspectString: Aspect.unknown.name,
            rockTypeString: RockType.limestone.name,
            climbingTypesString: [ClimbingType.sport.name],
            sourceString: CragSource.fetched.name,
            isSummaryOnly: isSummaryOnly,
          ));
        }

        if (!isSummaryOnly && areaMap['children'] != null) {
          final children = areaMap['children'] as List<dynamic>;
          for (final child in children) {
            final childMap = child as Map<String, dynamic>;
            final childMetadata =
                childMap['metadata'] as Map<String, dynamic>?;

            if (childMetadata != null &&
                childMetadata['lat'] != null &&
                childMetadata['lng'] != null) {
              crags.add(CragModel(
                id: childMap['area_name'] ?? 'unknown',
                name: childMap['area_name'] ?? 'Unknown Crag',
                latitude: (childMetadata['lat'] as num).toDouble(),
                longitude: (childMetadata['lng'] as num).toDouble(),
                aspectString: Aspect.unknown.name,
                rockTypeString: RockType.limestone.name,
                climbingTypesString: [ClimbingType.sport.name],
                sourceString: CragSource.fetched.name,
                isSummaryOnly: false,
              ));
            }
          }
        }
      }
    }

    return crags;
  }
}
