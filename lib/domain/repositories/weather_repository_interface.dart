import '../../domain/entities/weather.dart';

abstract class WeatherRepositoryInterface {
  Future<Weather> getWeather({
    required double latitude,
    required double longitude,
  });
}
