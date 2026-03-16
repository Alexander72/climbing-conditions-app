import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/aspect.dart';
import '../../domain/entities/rock_type.dart';
import '../../domain/entities/climbing_type.dart';
import '../../domain/entities/crag_source.dart';

part 'crag_model.g.dart';

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
  });

  factory CragModel.fromJson(Map<String, dynamic> json) =>
      _$CragModelFromJson(json);

  Map<String, dynamic> toJson() => _$CragModelToJson(this);

  factory CragModel.fromEntity(Crag crag) {
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
    );
  }
}
