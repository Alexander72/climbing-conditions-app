class GradeHistogramBin {
  final String grade;
  final int count;

  const GradeHistogramBin({
    required this.grade,
    required this.count,
  });
}

/// Route statistics from the catalog API (nullable fields when unknown).
class CragRouteStats {
  final int? routeCount;
  final int? sportCount;
  final int? tradNPCount;
  final int? boulderCount;
  final int? dwsCount;
  final List<GradeHistogramBin> gradeHistogram;

  const CragRouteStats({
    this.routeCount,
    this.sportCount,
    this.tradNPCount,
    this.boulderCount,
    this.dwsCount,
    this.gradeHistogram = const [],
  });

  bool get hasAnyData =>
      (routeCount != null && routeCount! > 0) ||
      (sportCount != null && sportCount! > 0) ||
      (tradNPCount != null && tradNPCount! > 0) ||
      (boulderCount != null && boulderCount! > 0) ||
      (dwsCount != null && dwsCount! > 0) ||
      gradeHistogram.isNotEmpty;
}
