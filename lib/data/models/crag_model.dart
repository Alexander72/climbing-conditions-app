import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/aspect.dart';
import '../../domain/entities/rock_type.dart';
import '../../domain/entities/climbing_type.dart';
import '../../domain/entities/crag_source.dart';
import '../../domain/entities/crag_route_stats.dart';

part 'crag_model.g.dart';

class GradeHistogramBinModel {
  final String grade;
  final int count;

  const GradeHistogramBinModel({
    required this.grade,
    required this.count,
  });

  factory GradeHistogramBinModel.fromJson(Map<String, dynamic> json) =>
      GradeHistogramBinModel(
        grade: json['grade'] as String,
        count: (json['count'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'grade': grade, 'count': count};

  GradeHistogramBin toEntity() =>
      GradeHistogramBin(grade: grade, count: count);
}

List<GradeHistogramBinModel>? _gradeHistogramFromJson(dynamic json) {
  if (json == null) return null;
  dynamic raw = json;
  if (raw is String) {
    if (raw.isEmpty) return null;
    raw = jsonDecode(raw);
  }
  if (raw is! List<dynamic>) return null;
  return raw
      .map((e) => GradeHistogramBinModel.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          ))
      .toList();
}

Object? _gradeHistogramToJson(List<GradeHistogramBinModel>? v) =>
    v?.map((e) => e.toJson()).toList();

@JsonSerializable()
class CragModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'aspect')
  final String aspectString;
  @JsonKey(name: 'rockType')
  final String rockTypeString;
  @JsonKey(name: 'climbingTypes')
  final List<String> climbingTypesString;
  final double? elevation;
  final String? description;
  @JsonKey(name: 'source')
  final String sourceString;
  final bool isSummaryOnly;
  final int? routeCount;
  final int? sportCount;
  @JsonKey(name: 'tradNPCount')
  final int? tradNPCount;
  final int? boulderCount;
  final int? dwsCount;
  @JsonKey(fromJson: _gradeHistogramFromJson, toJson: _gradeHistogramToJson)
  final List<GradeHistogramBinModel>? gradeHistogram;

  @JsonKey(name: 'weatherCellId')
  final String? weatherCellId;
  @JsonKey(name: 'conditionScore')
  final int? conditionScore;
  @JsonKey(name: 'conditionRecommendation')
  final String? conditionRecommendation;
  @JsonKey(name: 'conditionFactors')
  final List<String>? conditionFactors;
  @JsonKey(name: 'conditionLastUpdated')
  final int? conditionLastUpdated;
  @JsonKey(name: 'weatherAsOf')
  final String? weatherAsOf;

  CragModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.aspectString,
    required this.rockTypeString,
    required this.climbingTypesString,
    this.elevation,
    this.description,
    required this.sourceString,
    this.isSummaryOnly = false,
    this.routeCount,
    this.sportCount,
    this.tradNPCount,
    this.boulderCount,
    this.dwsCount,
    this.gradeHistogram,
    this.weatherCellId,
    this.conditionScore,
    this.conditionRecommendation,
    this.conditionFactors,
    this.conditionLastUpdated,
    this.weatherAsOf,
  });

  factory CragModel.fromJson(Map<String, dynamic> json) =>
      _$CragModelFromJson(json);

  Map<String, dynamic> toJson() => _$CragModelToJson(this);

  factory CragModel.fromEntity(Crag crag) {
    final rs = crag.routeStats;
    return CragModel(
      id: crag.id,
      name: crag.name,
      latitude: crag.latitude,
      longitude: crag.longitude,
      aspectString: crag.aspect.name,
      rockTypeString: crag.rockType.name,
      climbingTypesString: crag.climbingTypes.map((e) => e.name).toList(),
      elevation: crag.elevation,
      description: crag.description,
      sourceString: crag.source.name,
      isSummaryOnly: crag.isSummaryOnly,
      routeCount: rs?.routeCount,
      sportCount: rs?.sportCount,
      tradNPCount: rs?.tradNPCount,
      boulderCount: rs?.boulderCount,
      dwsCount: rs?.dwsCount,
      gradeHistogram: rs == null || rs.gradeHistogram.isEmpty
          ? null
          : rs.gradeHistogram
              .map(
                (b) => GradeHistogramBinModel(grade: b.grade, count: b.count),
              )
              .toList(),
      weatherCellId: crag.weatherCellId,
      conditionScore: crag.conditionScore,
      conditionRecommendation: crag.conditionRecommendation,
      conditionFactors: crag.conditionFactors,
      conditionLastUpdated: crag.conditionLastUpdated,
      weatherAsOf: crag.weatherAsOf,
    );
  }

  Crag toEntity() {
    return Crag(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      aspect: Aspect.values.firstWhere(
        (e) => e.name == aspectString,
        orElse: () => Aspect.unknown,
      ),
      rockType: RockType.values.firstWhere(
        (e) => e.name == rockTypeString,
        orElse: () => RockType.sandstone,
      ),
      climbingTypes: climbingTypesString
          .map((s) => ClimbingType.values.firstWhere(
                (e) => e.name == s,
                orElse: () => ClimbingType.sport,
              ))
          .toList(),
      elevation: elevation,
      description: description,
      source: CragSource.values.firstWhere(
        (e) => e.name == sourceString,
        orElse: () => CragSource.user,
      ),
      isSummaryOnly: isSummaryOnly,
      routeStats: _routeStatsToEntity(),
      weatherCellId: weatherCellId,
      conditionScore: conditionScore,
      conditionRecommendation: conditionRecommendation,
      conditionFactors: conditionFactors,
      conditionLastUpdated: conditionLastUpdated,
      weatherAsOf: weatherAsOf,
    );
  }

  CragRouteStats? _routeStatsToEntity() {
    final bins =
        gradeHistogram?.map((e) => e.toEntity()).toList() ?? const [];
    if (routeCount == null &&
        sportCount == null &&
        tradNPCount == null &&
        boulderCount == null &&
        dwsCount == null &&
        bins.isEmpty) {
      return null;
    }
    return CragRouteStats(
      routeCount: routeCount,
      sportCount: sportCount,
      tradNPCount: tradNPCount,
      boulderCount: boulderCount,
      dwsCount: dwsCount,
      gradeHistogram: bins,
    );
  }
}
