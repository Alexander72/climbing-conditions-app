import '../../domain/repositories/weather_repository_interface.dart';
import '../../domain/entities/weather.dart';
import '../datasources/backend_api_client.dart';
import '../database/app_database.dart';
import '../../core/config.dart';

class WeatherRepository implements WeatherRepositoryInterface {
  final BackendApiClient _apiClient;
  final AppDatabase _database;

  WeatherRepository({
    BackendApiClient? apiClient,
    AppDatabase? database,
  })  : _apiClient = apiClient ?? BackendApiClient(),
        _database = database ?? AppDatabase();

  @override
  Future<Weather> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    // Try to get from cache first
    final cached = await _database.getCachedWeather(
      latitude: latitude,
      longitude: longitude,
      maxAgeSeconds: AppConfig.weatherCacheExpiration,
    );

    if (cached != null) {
      return cached.toEntity();
    }

    // Fetch from API
    try {
      final weatherModel = await _apiClient.getWeather(
        latitude: latitude,
        longitude: longitude,
      );

      // Cache the result
      await _database.cacheWeather(
        latitude: latitude,
        longitude: longitude,
        weather: weatherModel,
      );

      return weatherModel.toEntity();
    } catch (e) {
      // If API fails and we have stale cache, return it
      final staleCache = await _database.getCachedWeather(
        latitude: latitude,
        longitude: longitude,
        maxAgeSeconds: AppConfig.weatherCacheExpiration * 24, // 24 hours
      );

      if (staleCache != null) {
        return staleCache.toEntity();
      }

      rethrow;
    }
  }
}
