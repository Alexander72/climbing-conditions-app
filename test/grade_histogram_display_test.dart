import 'package:flutter_test/flutter_test.dart';
import 'package:climbing_app/domain/entities/crag_route_stats.dart';
import 'package:climbing_app/presentation/utils/grade_histogram_display.dart';

void main() {
  test('normalizeGradeLabel strips trailing plus', () {
    expect(normalizeGradeLabel('6a+'), '6a');
    expect(normalizeGradeLabel('5+'), '5');
    expect(normalizeGradeLabel('  6b  '), '6b');
  });

  test('mergePlusGradeBins sums into base grade', () {
    final merged = mergePlusGradeBins([
      const GradeHistogramBin(grade: '6a', count: 3),
      const GradeHistogramBin(grade: '6a+', count: 2),
      const GradeHistogramBin(grade: '5+', count: 4),
      const GradeHistogramBin(grade: '5', count: 1),
    ]);
    final byGrade = {for (final b in merged) b.grade: b.count};
    expect(byGrade['6a'], 5);
    expect(byGrade['5'], 5);
  });

  test('compareGradeLabels orders numeric then French', () {
    expect(compareGradeLabels('4', '5'), lessThan(0));
    expect(compareGradeLabels('6a', '6b'), lessThan(0));
    expect(compareGradeLabels('6c', '7a'), lessThan(0));
  });
}
