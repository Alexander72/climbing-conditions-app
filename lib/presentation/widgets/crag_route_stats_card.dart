import 'package:flutter/material.dart';
import '../../domain/entities/crag_route_stats.dart';

/// Route counts, style breakdown, and grade histogram from the catalog API.
class CragRouteStatsCard extends StatelessWidget {
  final CragRouteStats? stats;

  const CragRouteStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null || !s.hasAnyData) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final maxBin = s.gradeHistogram.isEmpty
        ? 0
        : s.gradeHistogram.map((b) => b.count).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Routes',
              style: theme.textTheme.titleMedium,
            ),
            if (s.routeCount != null && s.routeCount! > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${s.routeCount} routes listed',
                style: theme.textTheme.bodyLarge,
              ),
            ],
            if (s.sportCount != null ||
                s.tradNPCount != null ||
                s.boulderCount != null ||
                s.dwsCount != null) ...[
              const SizedBox(height: 12),
              Text(
                'By style',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              _typeLine(theme, 'Sport', s.sportCount),
              _typeLine(theme, 'Trad / partially bolted', s.tradNPCount),
              _typeLine(theme, 'Boulder', s.boulderCount),
              _typeLine(theme, 'DWS', s.dwsCount),
            ],
            if (s.gradeHistogram.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'By grade (French)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...s.gradeHistogram.map(
                (bin) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          bin.grade,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final fill = maxBin > 0 ? bin.count / maxBin : 0.0;
                              return SizedBox(
                                height: 10,
                                width: w,
                                child: Stack(
                                  children: [
                                    ColoredBox(
                                      color:
                                          theme.colorScheme.surfaceContainerHighest,
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: w * fill,
                                        child: ColoredBox(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${bin.count}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeLine(ThemeData theme, String label, int? count) {
    if (count == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $count',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
