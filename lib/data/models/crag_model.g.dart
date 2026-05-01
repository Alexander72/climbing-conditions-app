// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crag_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CragModel _$CragModelFromJson(Map<String, dynamic> json) => CragModel(
  id: json['id'] as String,
  name: json['name'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  aspectString: json['aspect'] as String,
  rockTypeString: json['rockType'] as String,
  climbingTypesString: (json['climbingTypes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  elevation: (json['elevation'] as num?)?.toDouble(),
  description: json['description'] as String?,
  sourceString: json['source'] as String,
  isSummaryOnly: json['isSummaryOnly'] as bool? ?? false,
  routeCount: (json['routeCount'] as num?)?.toInt(),
  sportCount: (json['sportCount'] as num?)?.toInt(),
  tradNPCount: (json['tradNPCount'] as num?)?.toInt(),
  boulderCount: (json['boulderCount'] as num?)?.toInt(),
  dwsCount: (json['dwsCount'] as num?)?.toInt(),
  gradeHistogram: _gradeHistogramFromJson(json['gradeHistogram']),
  weatherCellId: json['weatherCellId'] as String?,
  conditionScore: (json['conditionScore'] as num?)?.toInt(),
  conditionRecommendation: json['conditionRecommendation'] as String?,
  conditionFactors: (json['conditionFactors'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  conditionLastUpdated: (json['conditionLastUpdated'] as num?)?.toInt(),
  conditionForecast: _conditionForecastFromJson(json['conditionForecast']),
  weatherAsOf: json['weatherAsOf'] as String?,
);

Map<String, dynamic> _$CragModelToJson(CragModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'aspect': instance.aspectString,
  'rockType': instance.rockTypeString,
  'climbingTypes': instance.climbingTypesString,
  'elevation': instance.elevation,
  'description': instance.description,
  'source': instance.sourceString,
  'isSummaryOnly': instance.isSummaryOnly,
  'routeCount': instance.routeCount,
  'sportCount': instance.sportCount,
  'tradNPCount': instance.tradNPCount,
  'boulderCount': instance.boulderCount,
  'dwsCount': instance.dwsCount,
  'gradeHistogram': _gradeHistogramToJson(instance.gradeHistogram),
  'weatherCellId': instance.weatherCellId,
  'conditionScore': instance.conditionScore,
  'conditionRecommendation': instance.conditionRecommendation,
  'conditionFactors': instance.conditionFactors,
  'conditionLastUpdated': instance.conditionLastUpdated,
  'conditionForecast': _conditionForecastToJson(instance.conditionForecast),
  'weatherAsOf': instance.weatherAsOf,
};
