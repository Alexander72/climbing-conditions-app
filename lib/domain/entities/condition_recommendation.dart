enum ConditionRecommendation {
  excellent,
  good,
  fair,
  poor,
  dangerous;

  String get displayName {
    switch (this) {
      case ConditionRecommendation.excellent:
        return 'Excellent';
      case ConditionRecommendation.good:
        return 'Good';
      case ConditionRecommendation.fair:
        return 'Fair';
      case ConditionRecommendation.poor:
        return 'Poor';
      case ConditionRecommendation.dangerous:
        return 'Dangerous';
    }
  }
}
