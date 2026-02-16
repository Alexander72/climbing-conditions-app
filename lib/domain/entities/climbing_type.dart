enum ClimbingType {
  sport,
  trad,
  boulder;

  String get displayName {
    switch (this) {
      case ClimbingType.sport:
        return 'Sport';
      case ClimbingType.trad:
        return 'Trad';
      case ClimbingType.boulder:
        return 'Boulder';
    }
  }
}
