import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/weather.dart';

part 'weather_model.g.dart';

@JsonSerializable()
class WeatherModel {
  final CurrentWeatherModel current;
  final List<HistoricalWeatherModel> historical;
  final List<ForecastWeatherModel> forecast;

  WeatherModel({
    required this.current,
    required this.historical,
    required this.forecast,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) =>
      _$WeatherModelFromJson(json);

  Map<String, dynamic> toJson() => _$WeatherModelToJson(this);

  Weather toEntity() {
    return Weather(
      temperature: current.temperature,
      humidity: current.humidity,
      precipitation: current.precipitation,
      windSpeed: current.windSpeed,
      timestamp: DateTime.fromMillisecondsSinceEpoch(current.timestamp * 1000),
      historical: historical.map((h) => h.toEntity()).toList(),
      forecast: forecast.map((f) => f.toEntity()).toList(),
    );
  }
}

@JsonSerializable()
class CurrentWeatherModel {
  final double temp;
  final double humidity;
  final double? rain;
  final double windSpeed;
  final int dt;

  CurrentWeatherModel({
    required this.temp,
    required this.humidity,
    this.rain,
    required this.windSpeed,
    required this.dt,
  });

  factory CurrentWeatherModel.fromJson(Map<String, dynamic> json) =>
      _$CurrentWeatherModelFromJson(json);

  Map<String, dynamic> toJson() => _$CurrentWeatherModelToJson(this);

  double get temperature => temp;
  double? get precipitation => rain;
  int get timestamp => dt;
}

@JsonSerializable()
class HistoricalWeatherModel {
  final int dt;
  final double temp;
  final double? rain;

  HistoricalWeatherModel({
    required this.dt,
    required this.temp,
    this.rain,
  });

  factory HistoricalWeatherModel.fromJson(Map<String, dynamic> json) =>
      _$HistoricalWeatherModelFromJson(json);

  Map<String, dynamic> toJson() => _$HistoricalWeatherModelToJson(this);

  HistoricalWeather toEntity() {
    return HistoricalWeather(
      date: DateTime.fromMillisecondsSinceEpoch(dt * 1000),
      precipitation: rain,
      temperature: temp,
    );
  }
}

@JsonSerializable()
class ForecastWeatherModel {
  final int dt;
  final double temp;
  final double? rain;
  final double windSpeed;

  ForecastWeatherModel({
    required this.dt,
    required this.temp,
    this.rain,
    required this.windSpeed,
  });

  factory ForecastWeatherModel.fromJson(Map<String, dynamic> json) =>
      _$ForecastWeatherModelFromJson(json);

  Map<String, dynamic> toJson() => _$ForecastWeatherModelToJson(this);

  ForecastWeather toEntity() {
    return ForecastWeather(
      date: DateTime.fromMillisecondsSinceEpoch(dt * 1000),
      precipitation: rain,
      temperature: temp,
      windSpeed: windSpeed,
    );
  }
}
