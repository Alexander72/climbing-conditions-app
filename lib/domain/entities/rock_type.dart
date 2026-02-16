enum RockType {
  sandstone,
  granite,
  limestone;

  String get displayName {
    switch (this) {
      case RockType.sandstone:
        return 'Sandstone';
      case RockType.granite:
        return 'Granite';
      case RockType.limestone:
        return 'Limestone';
    }
  }
}
