class AppConfig {
  // Backend API (proxies OpenWeatherMap and OpenBeta)
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:8000', // Set via --dart-define=BACKEND_BASE_URL=...
  );
  
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
