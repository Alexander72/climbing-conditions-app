import '../entities/crag.dart';
import '../entities/weather.dart';
import '../entities/condition.dart';
import '../entities/condition_recommendation.dart';
import '../entities/aspect.dart';
import '../entities/rock_type.dart';
import '../entities/climbing_type.dart';
import '../../core/config.dart';

class ConditionCalculator {
  Condition calculateCondition({
    required Crag crag,
    required Weather weather,
  }) {
    int score = 100;
    final factors = <String>[];

    // 1. Recent Precipitation Factor (0-30 points)
    final recentPrecipitationScore = _calculateRecentPrecipitationScore(
      weather.historical,
      factors,
    );
    score -= (30 - recentPrecipitationScore);

    // 2. Current Weather Factor (0-25 points)
    final currentWeatherScore = _calculateCurrentWeatherScore(
      weather,
      factors,
    );
    score -= (25 - currentWeatherScore);

    // 3. Aspect Factor (0-20 points)
    final aspectScore = _calculateAspectScore(
      crag.aspect,
      weather.historical,
      factors,
    );
    score -= (20 - aspectScore);

    // 4. Rock Type Factor (0-15 points)
    final rockTypeScore = _calculateRockTypeScore(
      crag.rockType,
      weather.historical,
      weather.precipitation,
      factors,
    );
    score -= (15 - rockTypeScore);

    // 5. Climbing Style Factor (0-10 points)
    final climbingStyleScore = _calculateClimbingStyleScore(
      crag.climbingTypes,
      score,
      factors,
    );
    score -= (10 - climbingStyleScore);

    // Apply special penalties for dangerous combinations
    score = _applySpecialPenalties(
      crag,
      weather,
      score,
      factors,
    );

    // Ensure score is within bounds
    score = score.clamp(0, 100);

    final recommendation = _getRecommendation(score);

    return Condition(
      score: score,
      recommendation: recommendation,
      factors: factors,
      lastUpdated: DateTime.now(),
    );
  }

  int _calculateRecentPrecipitationScore(
    List<HistoricalWeather> historical,
    List<String> factors,
  ) {
    if (historical.isEmpty) {
      factors.add('No historical weather data available');
      return 15; // Neutral score
    }

    // Check precipitation in last 5 days
    final now = DateTime.now();
    final recentDays = historical.where((h) {
      final daysDiff = now.difference(h.date).inDays;
      return daysDiff <= 5;
    }).toList();

    if (recentDays.isEmpty) {
      factors.add('No recent precipitation data');
      return 15;
    }

    // Count days with precipitation
    int daysWithRain = 0;

    for (final day in recentDays) {
      if (day.precipitation != null && day.precipitation! > 0) {
        daysWithRain++;
      }
    }

    if (daysWithRain == 0) {
      factors.add('No precipitation in the last 5 days');
      return 30; // Full points
    }

    // More recent rain = lower score
    final mostRecentRain = recentDays
        .where((d) => d.precipitation != null && d.precipitation! > 0)
        .toList();
    if (mostRecentRain.isNotEmpty) {
      mostRecentRain.sort((a, b) => b.date.compareTo(a.date));
      final daysSinceRain = now.difference(mostRecentRain.first.date).inDays;

      if (daysSinceRain == 0) {
        factors.add('Rain today - conditions poor');
        return 0;
      } else if (daysSinceRain == 1) {
        factors.add('Rain yesterday - rock may still be wet');
        return 5;
      } else if (daysSinceRain == 2) {
        factors.add('Rain 2 days ago - drying conditions');
        return 10;
      } else if (daysSinceRain == 3) {
        factors.add('Rain 3 days ago - mostly dry');
        return 20;
      } else {
        factors.add('Rain ${daysSinceRain} days ago - should be dry');
        return 25;
      }
    }

    return 15;
  }

  int _calculateCurrentWeatherScore(
    Weather weather,
    List<String> factors,
  ) {
    int score = 25;

    // Current precipitation
    if (weather.precipitation != null && weather.precipitation! > 0) {
      factors.add('Currently raining - not recommended');
      return 0;
    }

    // Temperature check
    if (weather.temperature < AppConfig.minTemperature) {
      factors.add('Temperature too cold (${weather.temperature.toStringAsFixed(1)}°C)');
      score -= 10;
    } else if (weather.temperature > 35) {
      factors.add('Temperature very hot (${weather.temperature.toStringAsFixed(1)}°C)');
      score -= 5;
    } else {
      factors.add('Temperature good (${weather.temperature.toStringAsFixed(1)}°C)');
    }

    // Wind speed check
    if (weather.windSpeed > AppConfig.maxWindSpeed) {
      factors.add('Wind speed too high (${weather.windSpeed.toStringAsFixed(1)} m/s)');
      score -= 10;
    } else if (weather.windSpeed > 20) {
      factors.add('Moderate wind (${weather.windSpeed.toStringAsFixed(1)} m/s)');
      score -= 5;
    }

    return score.clamp(0, 25);
  }

  int _calculateAspectScore(
    Aspect aspect,
    List<HistoricalWeather> historical,
    List<String> factors,
  ) {
    // Check if there was recent rain
    final hasRecentRain = historical.any((h) {
      final daysDiff = DateTime.now().difference(h.date).inDays;
      return daysDiff <= 3 &&
          h.precipitation != null &&
          h.precipitation! > 0;
    });

    if (!hasRecentRain) {
      factors.add('${aspect.displayName}-facing: No recent rain concerns');
      return 20; // Full points if no rain
    }

    // Aspect affects drying speed
    switch (aspect) {
      case Aspect.north:
      case Aspect.northeast:
      case Aspect.northwest:
        factors.add(
          '${aspect.displayName}-facing: Slower drying, more shade',
        );
        return 10; // Lower score for north-facing
      case Aspect.south:
      case Aspect.southeast:
      case Aspect.southwest:
        factors.add(
          '${aspect.displayName}-facing: Faster drying, more sun',
        );
        return 18; // Higher score for south-facing
      case Aspect.east:
      case Aspect.west:
        factors.add(
          '${aspect.displayName}-facing: Moderate drying',
        );
        return 15; // Moderate score
      case Aspect.unknown:
        factors.add('Aspect unknown: Assuming moderate conditions');
        return 12;
    }
  }

  int _calculateRockTypeScore(
    RockType rockType,
    List<HistoricalWeather> historical,
    double? currentPrecipitation,
    List<String> factors,
  ) {
    // Check for recent rain
    final hasRecentRain = historical.any((h) {
      final daysDiff = DateTime.now().difference(h.date).inDays;
      return daysDiff <= 3 &&
          h.precipitation != null &&
          h.precipitation! > 0;
    }) || (currentPrecipitation != null && currentPrecipitation > 0);

    if (!hasRecentRain) {
      factors.add('${rockType.displayName}: No moisture concerns');
      return 15; // Full points
    }

    switch (rockType) {
      case RockType.sandstone:
        factors.add(
          '${rockType.displayName}: Very sensitive to moisture, brittle when wet',
        );
        return 0; // Very low score
      case RockType.granite:
        factors.add(
          '${rockType.displayName}: More resistant but still affected by moisture',
        );
        return 8; // Moderate-low score
      case RockType.limestone:
        factors.add(
          '${rockType.displayName}: Moderate sensitivity to moisture',
        );
        return 10; // Moderate score
    }
  }

  int _calculateClimbingStyleScore(
    List<ClimbingType> climbingTypes,
    int currentScore,
    List<String> factors,
  ) {
    // Climbing style affects how forgiving conditions are
    if (climbingTypes.contains(ClimbingType.sport)) {
      factors.add('Sport climbing: More forgiving conditions');
      return 10; // Full points
    } else if (climbingTypes.contains(ClimbingType.trad)) {
      factors.add('Trad climbing: Requires better conditions');
      return 7; // Lower score
    } else if (climbingTypes.contains(ClimbingType.boulder)) {
      factors.add('Bouldering: Can be sensitive to conditions');
      return 8; // Moderate score
    }
    return 10;
  }

  int _applySpecialPenalties(
    Crag crag,
    Weather weather,
    int score,
    List<String> factors,
  ) {
    // Special penalty: Sandstone + North-facing + Recent rain
    final hasRecentRain = weather.historical.any((h) {
      final daysDiff = DateTime.now().difference(h.date).inDays;
      return daysDiff <= 3 &&
          h.precipitation != null &&
          h.precipitation! > 0;
    }) || (weather.precipitation != null && weather.precipitation! > 0);

    if (crag.rockType == RockType.sandstone &&
        (crag.aspect == Aspect.north ||
            crag.aspect == Aspect.northeast ||
            crag.aspect == Aspect.northwest) &&
        hasRecentRain) {
      score -= 40;
      factors.add(
        'CRITICAL: Sandstone + North-facing + Recent rain = Very dangerous conditions',
      );
    }

    return score;
  }

  ConditionRecommendation _getRecommendation(int score) {
    if (score >= 80) {
      return ConditionRecommendation.excellent;
    } else if (score >= 60) {
      return ConditionRecommendation.good;
    } else if (score >= 40) {
      return ConditionRecommendation.fair;
    } else if (score >= 20) {
      return ConditionRecommendation.poor;
    } else {
      return ConditionRecommendation.dangerous;
    }
  }
}
