import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/condition_recommendation.dart';

part 'condition_model.g.dart';

@JsonSerializable()
class ConditionModel {
  final int score;
  @JsonKey(name: 'recommendation')
  final String recommendationString;
  final List<String> factors;
  final int lastUpdated;

  ConditionModel({
    required this.score,
    required this.recommendationString,
    required this.factors,
    required this.lastUpdated,
  });

  factory ConditionModel.fromJson(Map<String, dynamic> json) =>
      _$ConditionModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConditionModelToJson(this);

  factory ConditionModel.fromEntity(Condition condition) {
    return ConditionModel(
      score: condition.score,
      recommendationString: condition.recommendation.name,
      factors: condition.factors,
      lastUpdated: condition.lastUpdated.millisecondsSinceEpoch ~/ 1000,
    );
  }

  Condition toEntity() {
    return Condition(
      score: score,
      recommendation: ConditionRecommendation.values.firstWhere(
        (e) => e.name == recommendationString,
        orElse: () => ConditionRecommendation.fair,
      ),
      factors: factors,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(lastUpdated * 1000),
    );
  }
}
