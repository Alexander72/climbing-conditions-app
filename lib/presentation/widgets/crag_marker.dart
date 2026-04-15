import 'package:flutter/material.dart';
import '../../domain/entities/crag.dart';

/// Map marker for a crag.
///
/// Summary mode (zoom 7–9 or isSummaryOnly): small grey/blue dot — presence only.
/// Detailed mode (zoom > 9 and !isSummaryOnly): colored circle with score from backend
/// when available; grey placeholder when capped or weather missing.
class CragMarker extends StatelessWidget {
  final Crag crag;
  final bool isDetailed;

  const CragMarker({
    super.key,
    required this.crag,
    required this.isDetailed,
  });

  static Color _scoreColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDetailed || crag.isSummaryOnly) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade400,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }

    final score = crag.conditionScore;
    if (score == null) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade500,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Center(
          child: Text(
            '—',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _scoreColor(score),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '$score',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
