class Weather {
  final double temperature;
  final double humidity;
  final double? precipitation;
  final double windSpeed;
  final DateTime timestamp;
  final List<HistoricalWeather> historical;
  final List<ForecastWeather> forecast;

  const Weather({
    required this.temperature,
    required this.humidity,
    this.precipitation,
    required this.windSpeed,
    required this.timestamp,
    required this.historical,
    required this.forecast,
  });
}

class HistoricalWeather {
  final DateTime date;
  final double? precipitation;
  final double temperature;

  const HistoricalWeather({
    required this.date,
    this.precipitation,
    required this.temperature,
  });
}

class ForecastWeather {
  final DateTime date;
  final double? precipitation;
  final double temperature;
  final double windSpeed;

  const ForecastWeather({
    required this.date,
    this.precipitation,
    required this.temperature,
    required this.windSpeed,
  });
}
