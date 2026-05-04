class AppConfig {
  // Backend API (OpenWeatherMap proxy + local crag catalog)
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
  /// Must be >= 7.0 so [CragProvider.visibleCrags] is non-empty before the first
  /// map [MapEventMoveEnd] (markers use the same filter as the list viewport).
  static const double defaultMapZoom = 7.5;
  
  // Condition calculation defaults
  static const int minTemperature = -5; // Celsius
  static const int maxWindSpeed = 30; // m/s
}
