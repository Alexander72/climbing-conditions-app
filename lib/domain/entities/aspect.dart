enum Aspect {
  north,
  northeast,
  east,
  southeast,
  south,
  southwest,
  west,
  northwest,
  unknown;

  String get displayName {
    switch (this) {
      case Aspect.north:
        return 'North';
      case Aspect.northeast:
        return 'Northeast';
      case Aspect.east:
        return 'East';
      case Aspect.southeast:
        return 'Southeast';
      case Aspect.south:
        return 'South';
      case Aspect.southwest:
        return 'Southwest';
      case Aspect.west:
        return 'West';
      case Aspect.northwest:
        return 'Northwest';
      case Aspect.unknown:
        return 'Unknown';
    }
  }
}
