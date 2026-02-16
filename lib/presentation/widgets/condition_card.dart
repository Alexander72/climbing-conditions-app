import 'package:flutter/material.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/condition_recommendation.dart';

class ConditionCard extends StatelessWidget {
  final Condition condition;

  const ConditionCard({
    super.key,
    required this.condition,
  });

  Color _getRecommendationColor(ConditionRecommendation recommendation) {
    switch (recommendation) {
      case ConditionRecommendation.excellent:
        return Colors.green;
      case ConditionRecommendation.good:
        return Colors.lightGreen;
      case ConditionRecommendation.fair:
        return Colors.orange;
      case ConditionRecommendation.poor:
        return Colors.deepOrange;
      case ConditionRecommendation.dangerous:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getRecommendationColor(condition.recommendation).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '${condition.score}',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getRecommendationColor(condition.recommendation),
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getRecommendationColor(condition.recommendation),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                condition.recommendation.displayName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...condition.factors.map(
              (factor) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: _getRecommendationColor(condition.recommendation),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        factor,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
