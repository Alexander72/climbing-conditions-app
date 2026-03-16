import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/crag.dart';
import '../providers/condition_provider.dart';
import '../providers/weather_provider.dart';

/// Map marker for a crag.
///
/// Summary mode (zoom 7–9 or isSummaryOnly): small grey/blue dot — presence only.
/// Detailed mode (zoom > 9 and !isSummaryOnly): colored circle with score number.
///   green ≥ 75 · orange 50–74 · red < 50
class CragMarker extends StatefulWidget {
  final Crag crag;
  final bool isDetailed;

  const CragMarker({
    super.key,
    required this.crag,
    required this.isDetailed,
  });

  @override
  State<CragMarker> createState() => _CragMarkerState();
}

class _CragMarkerState extends State<CragMarker> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isDetailed && !widget.crag.isSummaryOnly) {
      _ensureConditionLoaded();
    }
  }

  void _ensureConditionLoaded() {
    final conditionProvider = context.read<ConditionProvider>();
    if (conditionProvider.getCondition(widget.crag.id) != null) return;
    if (conditionProvider.isLoading(widget.crag.id)) return;

    final weatherProvider = context.read<WeatherProvider>();
    weatherProvider
        .fetchWeather(
          latitude: widget.crag.latitude,
          longitude: widget.crag.longitude,
        )
        .then((weather) {
          if (!mounted) return;
          conditionProvider.calculateCondition(
            crag: widget.crag,
            weather: weather,
          );
        })
        .catchError((_) {});
  }

  static Color _scoreColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    // Summary tier: small presence dot
    if (!widget.isDetailed || widget.crag.isSummaryOnly) {
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

    // Detailed tier: colored circle with score
    return Consumer<ConditionProvider>(
      builder: (context, conditionProvider, _) {
        final condition = conditionProvider.getCondition(widget.crag.id);
        final isLoading = conditionProvider.isLoading(widget.crag.id);

        if (isLoading || condition == null) {
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _scoreColor(condition.score),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text(
              '${condition.score}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
