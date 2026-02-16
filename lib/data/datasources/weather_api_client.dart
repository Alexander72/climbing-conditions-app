import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../../core/config.dart';

class WeatherApiClient {
  final http.Client _client;
  final String _apiKey;

  WeatherApiClient({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AppConfig.openWeatherMapApiKey;

  Future<WeatherModel> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenWeatherMap API key is not set');
    }

    final uri = Uri.parse(AppConfig.openWeatherMapBaseUrl).replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'appid': _apiKey,
        'units': 'metric',
      },
    );

    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return _parseWeatherResponse(jsonData);
      } else {
        throw Exception(
          'Failed to fetch weather: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching weather data: $e');
    }
  }

  WeatherModel _parseWeatherResponse(Map<String, dynamic> json) {
    // Parse current weather
    final current = json['current'] as Map<String, dynamic>;
    final currentWeather = CurrentWeatherModel(
      temp: (current['temp'] as num).toDouble(),
      humidity: (current['humidity'] as num).toDouble(),
      rain: current['rain']?['1h'] as double?,
      windSpeed: (current['wind_speed'] as num).toDouble(),
      dt: current['dt'] as int,
    );

    // Parse historical data (last 5 days)
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

    // Parse forecast (next 48 hours)
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
}
