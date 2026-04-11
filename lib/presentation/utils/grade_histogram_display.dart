import 'package:flutter/material.dart';
import '../../domain/entities/crag_route_stats.dart';

/// Strips a trailing `+` so `6a+` counts merge into `6a`, `5+` into `5`.
String normalizeGradeLabel(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  if (s.endsWith('+')) {
    return s.substring(0, s.length - 1).trim();
  }
  return s;
}

/// Merges histogram bins that only differ by a trailing `+` on the label.
List<GradeHistogramBin> mergePlusGradeBins(List<GradeHistogramBin> bins) {
  final merged = <String, int>{};
  for (final b in bins) {
    final key = normalizeGradeLabel(b.grade);
    merged[key] = (merged[key] ?? 0) + b.count;
  }
  final keys = merged.keys.toList()..sort(compareGradeLabels);
  return keys
      .map((k) => GradeHistogramBin(grade: k, count: merged[k]!))
      .toList();
}

/// True when this bin should not be shown (no usable grade).
bool isUnknownGradeLabel(String raw) {
  final g = raw.trim().toLowerCase();
  if (g.isEmpty) return true;
  if (g == '?' || g == '？') return true;
  if (g == 'n/a' || g == 'na' || g == 'none' || g == 'unknown') return true;
  if (int.tryParse(g) == 0) return true;
  return false;
}

/// Merges numeric bands `3` and `4` into a single bar labeled `4`.
List<GradeHistogramBin> mergeNumericGrade34(List<GradeHistogramBin> bins) {
  const mergedLabel = '4';
  final merged = <String, int>{};
  for (final b in bins) {
    final k = b.grade.trim();
    if (k == '3' || k == '4') {
      merged[mergedLabel] = (merged[mergedLabel] ?? 0) + b.count;
    } else {
      merged[k] = (merged[k] ?? 0) + b.count;
    }
  }
  final keys = merged.keys.toList()..sort(compareGradeLabels);
  return keys
      .map((k) => GradeHistogramBin(grade: k, count: merged[k]!))
      .toList();
}

/// Plus-variant merge, drop unknown-grade bins, merge `3` + `4` for display.
List<GradeHistogramBin> mergeGradeHistogramForDisplay(List<GradeHistogramBin> bins) {
  final plusMerged = mergePlusGradeBins(bins);
  final known =
      plusMerged.where((b) => !isUnknownGradeLabel(b.grade)).toList();
  return mergeNumericGrade34(known);
}

/// Sort key: numeric grades, then French-style `6a`…`9c`, then lexicographic fallback.
int compareGradeLabels(String a, String b) {
  final ka = _sortKey(a);
  final kb = _sortKey(b);
  final c = ka.compareTo(kb);
  if (c != 0) return c;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

double _sortKey(String g) {
  final lower = g.toLowerCase();
  final asInt = int.tryParse(lower);
  if (asInt != null) return asInt * 1000.0;

  final m = RegExp(r'^(\d+)([abc])$').firstMatch(lower);
  if (m != null) {
    final major = int.parse(m.group(1)!);
    final letter = m.group(2)!;
    final sub = letter == 'a' ? 1 : (letter == 'b' ? 2 : 3);
    return major * 1000.0 + sub.toDouble();
  }
  final tie = lower.codeUnits.fold<int>(0, (a, b) => a + b);
  return 450_000.0 + tie / 10_000.0;
}

/// Bar colors by difficulty tier (French sport / numeric entry grades).
Color gradeBarColor(String grade, {required Brightness brightness}) {
  final g = grade.trim().toLowerCase();
  final n = int.tryParse(g);
  if (n != null) {
    if (n <= 4) return const Color(0xFF9CCC65);
    if (n == 5) return const Color(0xFF7CB342);
    return const Color(0xFF689F38);
  }

  final m = RegExp(r'^(\d+)([abc])$').firstMatch(g);
  if (m != null) {
    final major = int.parse(m.group(1)!);
    final letter = m.group(2)!;
    if (major == 6) {
      return letter == 'a'
          ? const Color(0xFFFFD54F)
          : letter == 'b'
              ? const Color(0xFFFFC107)
              : const Color(0xFFFFB300);
    }
    if (major == 7) {
      return letter == 'a'
          ? const Color(0xFFFF9800)
          : letter == 'b'
              ? const Color(0xFFF57C00)
              : const Color(0xFFE65100);
    }
    if (major == 8) {
      return letter == 'a'
          ? const Color(0xFFAB47BC)
          : letter == 'b'
              ? const Color(0xFF9C27B0)
              : const Color(0xFF7B1FA2);
    }
    if (major >= 9) {
      return brightness == Brightness.dark
          ? const Color(0xFFE0E0E0)
          : const Color(0xFF212121);
    }
  }

  return const Color(0xFF90A4AE);
}
