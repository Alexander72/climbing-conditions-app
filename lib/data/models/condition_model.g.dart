// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'condition_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConditionModel _$ConditionModelFromJson(Map<String, dynamic> json) =>
    ConditionModel(
      score: (json['score'] as num).toInt(),
      recommendationString: json['recommendation'] as String,
      factors: (json['factors'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastUpdated: (json['lastUpdated'] as num).toInt(),
    );

Map<String, dynamic> _$ConditionModelToJson(ConditionModel instance) =>
    <String, dynamic>{
      'score': instance.score,
      'recommendation': instance.recommendationString,
      'factors': instance.factors,
      'lastUpdated': instance.lastUpdated,
    };
