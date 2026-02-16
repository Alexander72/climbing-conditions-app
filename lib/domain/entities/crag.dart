import 'aspect.dart';
import 'rock_type.dart';
import 'climbing_type.dart';
import 'crag_source.dart';

class Crag {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final Aspect aspect;
  final RockType rockType;
  final List<ClimbingType> climbingTypes;
  final double? elevation;
  final String? description;
  final CragSource source;

  const Crag({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.aspect,
    required this.rockType,
    required this.climbingTypes,
    this.elevation,
    this.description,
    required this.source,
  });
}
