// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeatherModel _$WeatherModelFromJson(Map<String, dynamic> json) => WeatherModel(
  current: CurrentWeatherModel.fromJson(
    json['current'] as Map<String, dynamic>,
  ),
  historical: (json['historical'] as List<dynamic>)
      .map((e) => HistoricalWeatherModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  forecast: (json['forecast'] as List<dynamic>)
      .map((e) => ForecastWeatherModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$WeatherModelToJson(WeatherModel instance) =>
    <String, dynamic>{
      'current': instance.current,
      'historical': instance.historical,
      'forecast': instance.forecast,
    };

CurrentWeatherModel _$CurrentWeatherModelFromJson(Map<String, dynamic> json) =>
    CurrentWeatherModel(
      temp: (json['temp'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      rain: (json['rain'] as num?)?.toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      dt: (json['dt'] as num).toInt(),
    );

Map<String, dynamic> _$CurrentWeatherModelToJson(
  CurrentWeatherModel instance,
) => <String, dynamic>{
  'temp': instance.temp,
  'humidity': instance.humidity,
  'rain': instance.rain,
  'windSpeed': instance.windSpeed,
  'dt': instance.dt,
};

HistoricalWeatherModel _$HistoricalWeatherModelFromJson(
  Map<String, dynamic> json,
) => HistoricalWeatherModel(
  dt: (json['dt'] as num).toInt(),
  temp: (json['temp'] as num).toDouble(),
  rain: (json['rain'] as num?)?.toDouble(),
);

Map<String, dynamic> _$HistoricalWeatherModelToJson(
  HistoricalWeatherModel instance,
) => <String, dynamic>{
  'dt': instance.dt,
  'temp': instance.temp,
  'rain': instance.rain,
};

ForecastWeatherModel _$ForecastWeatherModelFromJson(
  Map<String, dynamic> json,
) => ForecastWeatherModel(
  dt: (json['dt'] as num).toInt(),
  temp: (json['temp'] as num).toDouble(),
  rain: (json['rain'] as num?)?.toDouble(),
  windSpeed: (json['windSpeed'] as num).toDouble(),
);

Map<String, dynamic> _$ForecastWeatherModelToJson(
  ForecastWeatherModel instance,
) => <String, dynamic>{
  'dt': instance.dt,
  'temp': instance.temp,
  'rain': instance.rain,
  'windSpeed': instance.windSpeed,
};
