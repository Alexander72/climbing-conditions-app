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
};
