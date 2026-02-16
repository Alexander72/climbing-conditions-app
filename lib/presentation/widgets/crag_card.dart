import 'package:flutter/material.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/condition_recommendation.dart';

class CragCard extends StatelessWidget {
  final Crag crag;
  final Condition? condition;
  final VoidCallback onTap;

  const CragCard({
    super.key,
    required this.crag,
    this.condition,
    required this.onTap,
  });

  Color _getConditionColor(ConditionRecommendation recommendation) {
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      crag.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (condition != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getConditionColor(condition!.recommendation),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${condition!.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(crag.rockType.displayName),
                    avatar: const Icon(Icons.landscape, size: 18),
                  ),
                  Chip(
                    label: Text(crag.aspect.displayName),
                    avatar: const Icon(Icons.explore, size: 18),
                  ),
                  ...crag.climbingTypes.map(
                    (type) => Chip(
                      label: Text(type.displayName),
                      avatar: const Icon(Icons.arrow_upward, size: 18),
                    ),
                  ),
                ],
              ),
              if (condition != null && condition!.factors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  condition!.factors.first,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
