import 'condition_recommendation.dart';

class Condition {
  final int score;
  final ConditionRecommendation recommendation;
  final List<String> factors;
  final DateTime lastUpdated;

  const Condition({
    required this.score,
    required this.recommendation,
    required this.factors,
    required this.lastUpdated,
  });
}
