class AppConfig {
  // OpenWeatherMap API
  static const String openWeatherMapApiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '', // Set via --dart-define=OPENWEATHER_API_KEY=your_key
  );
  static const String openWeatherMapBaseUrl = 'https://api.openweathermap.org/data/3.0/onecall';
  
  // OpenBeta API
  static const String openBetaApiUrl = 'https://api.openbeta.io/graphql';
  
  // Cache expiration times (in seconds)
  static const int weatherCacheExpiration = 3600; // 1 hour
  static const int cragCacheExpiration = 86400; // 24 hours
  
  // Default map center (Germany/Belgium region)
  static const double defaultMapLatitude = 50.5;
  static const double defaultMapLongitude = 6.0;
  static const double defaultMapZoom = 6.0;
  
  // Condition calculation defaults
  static const int minTemperature = -5; // Celsius
  static const int maxWindSpeed = 30; // m/s
}
