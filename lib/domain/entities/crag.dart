import 'aspect.dart';
import 'condition.dart';
import 'condition_recommendation.dart';
import 'rock_type.dart';
import 'climbing_type.dart';
import 'crag_source.dart';
import 'crag_route_stats.dart';

class Crag {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final Aspect aspect;
  final RockType rockType;
  final List<ClimbingType> climbingTypes;
  final double? elevation;
  final String? description;
  final CragSource source;
  final bool isSummaryOnly;
  final CragRouteStats? routeStats;

  /// From backend `detail_level=full` / crag detail (null for summary tier or uncapped).
  final String? weatherCellId;
  final int? conditionScore;
  final String? conditionRecommendation;
  final List<String>? conditionFactors;
  final int? conditionLastUpdated;
  final String? weatherAsOf;

  const Crag({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.aspect,
    required this.rockType,
    required this.climbingTypes,
    this.elevation,
    this.description,
    required this.source,
    this.isSummaryOnly = false,
    this.routeStats,
    this.weatherCellId,
    this.conditionScore,
    this.conditionRecommendation,
    this.conditionFactors,
    this.conditionLastUpdated,
    this.weatherAsOf,
  });

  /// Condition derived from backend scores when present (avoids a second weather fetch).
  Condition? get backendDerivedCondition {
    final s = conditionScore;
    final recName = conditionRecommendation;
    if (s == null || recName == null) return null;
    final rec = ConditionRecommendation.values.firstWhere(
      (e) => e.name == recName,
      orElse: () => ConditionRecommendation.fair,
    );
    final ts = conditionLastUpdated ?? 0;
    return Condition(
      score: s,
      recommendation: rec,
      factors: conditionFactors ?? const [],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
    );
  }
}
