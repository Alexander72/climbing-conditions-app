import 'package:flutter/foundation.dart';
import '../../domain/entities/weather.dart';
import '../../data/repositories/weather_repository.dart';

class WeatherProvider with ChangeNotifier {
  final WeatherRepository _repository;
  final Map<String, Weather> _weatherCache = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errors = {};

  WeatherProvider({WeatherRepository? repository})
      : _repository = repository ?? WeatherRepository();

  Weather? getWeather(double latitude, double longitude) {
    final key = '${latitude}_$longitude';
    return _weatherCache[key];
  }

  bool isLoading(double latitude, double longitude) {
    final key = '${latitude}_$longitude';
    return _loadingStates[key] ?? false;
  }

  String? getError(double latitude, double longitude) {
    final key = '${latitude}_$longitude';
    return _errors[key];
  }

  Future<Weather> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final key = '${latitude}_$longitude';
    _loadingStates[key] = true;
    _errors[key] = null;
    notifyListeners();

    try {
      final weather = await _repository.getWeather(
        latitude: latitude,
        longitude: longitude,
      );
      _weatherCache[key] = weather;
      return weather;
    } catch (e) {
      _errors[key] = 'Failed to fetch weather: $e';
      rethrow;
    } finally {
      _loadingStates[key] = false;
      notifyListeners();
    }
  }

  void clearCache() {
    _weatherCache.clear();
    _errors.clear();
    notifyListeners();
  }
}
