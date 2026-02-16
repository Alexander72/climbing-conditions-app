enum CragSource {
  preloaded,
  fetched,
  user;

  String get displayName {
    switch (this) {
      case CragSource.preloaded:
        return 'Pre-loaded';
      case CragSource.fetched:
        return 'Fetched';
      case CragSource.user:
        return 'User Added';
    }
  }
}
