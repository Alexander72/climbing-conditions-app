import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../domain/entities/crag_route_stats.dart';
import '../utils/grade_histogram_display.dart';

const _kStyleIconCircleColor = Color(0xFFFFD54F);

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
    final brightness = theme.brightness;
    final mergedHistogram = mergePlusGradeBins(s.gradeHistogram);
    final maxBin = mergedHistogram.isEmpty
        ? 0
        : mergedHistogram.map((b) => b.count).reduce((a, b) => a > b ? a : b);

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
                s.boulderCount != null) ...[
              const SizedBox(height: 16),
              _StyleSummaryRow(
                sport: s.sportCount,
                trad: s.tradNPCount,
                boulder: s.boulderCount,
              ),
            ],
            if (s.dwsCount != null) ...[
              const SizedBox(height: 8),
              Text('DWS: ${s.dwsCount}', style: theme.textTheme.bodyMedium),
            ],
            if (mergedHistogram.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'By grade (French)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              _ResponsiveGradeHistogram(
                bins: mergedHistogram,
                maxCount: maxBin,
                brightness: brightness,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Histogram sizing: uses available width and screen size; thin bars + scroll on narrow widths.
class _ResponsiveGradeHistogram extends StatelessWidget {
  final List<GradeHistogramBin> bins;
  final int maxCount;
  final Brightness brightness;

  const _ResponsiveGradeHistogram({
    required this.bins,
    required this.maxCount,
    required this.brightness,
  });

  static const double _minBarWidth = 7;
  static const double _maxBarWidthFit = 20;
  static const double _minColumnWhenFit = 17;
  /// Grade label + padding below chart (per-bin count is inside chart height).
  static const double _labelBlockH = 30;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final sh = mq.height;
    final sw = mq.width;

    // Chart area scales with window height (tighter on short portrait screens).
    final chartHeight = (sh * 0.13).clamp(72.0, 148.0);
    final minBarHeight = math.max(8.0, chartHeight * 0.07);
    final totalHeight = chartHeight + _labelBlockH;

    return LayoutBuilder(
      builder: (context, c) {
        final availW = c.maxWidth.isFinite ? c.maxWidth : sw;
        final n = bins.length;
        if (n == 0) return const SizedBox.shrink();

        final gapNarrow = sw < 380 ? 3.0 : 5.0;
        final gapWide = sw < 420 ? 5.0 : 8.0;

        // Try fitting all columns without horizontal scroll.
        final gapFit = n > 8 ? gapNarrow : gapWide;
        var colW = (availW - (n - 1) * gapFit) / n;
        var barW = (colW - 6).clamp(_minBarWidth, _maxBarWidthFit);
        var useScroll = colW < _minColumnWhenFit;

        double gap;
        double columnWidth;
        if (useScroll) {
          gap = gapNarrow;
          barW = sw < 360 ? 8.0 : 10.0;
          columnWidth = barW + 6;
        } else {
          gap = gapFit;
          colW = (availW - (n - 1) * gap) / n;
          barW = (colW - 6).clamp(_minBarWidth, _maxBarWidthFit);
          columnWidth = colW;
        }

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: columnWidth,
                height: totalHeight,
                child: _GradeBarColumn(
                  bin: bins[i],
                  maxCount: maxCount,
                  barColor: gradeBarColor(
                    bins[i].grade,
                    brightness: brightness,
                  ),
                  chartHeight: chartHeight,
                  minBarHeight: minBarHeight,
                  barWidth: barW,
                ),
              ),
            ],
          ],
        );

        return SizedBox(
          height: totalHeight,
          width: availW,
          child: useScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: row,
                )
              : row,
        );
      },
    );
  }
}

class _StyleSummaryRow extends StatelessWidget {
  final int? sport;
  final int? trad;
  final int? boulder;

  const _StyleSummaryRow({
    required this.sport,
    required this.trad,
    required this.boulder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <({String label, int count, IconData icon, String? tip})>[];
    if (sport != null) {
      items.add((label: 'Sport', count: sport!, icon: Icons.bolt_rounded, tip: null));
    }
    if (trad != null) {
      items.add((
        label: 'Trad',
        count: trad!,
        icon: Icons.landscape_rounded,
        tip: 'Includes traditional and partially bolted routes',
      ));
    }
    if (boulder != null) {
      items.add((
        label: 'Boulder',
        count: boulder!,
        icon: Icons.square_foot_rounded,
        tip: null,
      ));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((e) {
        Widget column = Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: _kStyleIconCircleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                e.icon,
                size: 26,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${e.count} ${e.label}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
        if (e.tip != null) {
          column = Tooltip(message: e.tip!, child: column);
        }
        return Expanded(child: column);
      }).toList(),
    );
  }
}

class _GradeBarColumn extends StatelessWidget {
  final GradeHistogramBin bin;
  final int maxCount;
  final Color barColor;
  final double chartHeight;
  final double minBarHeight;
  final double barWidth;

  const _GradeBarColumn({
    required this.bin,
    required this.maxCount,
    required this.barColor,
    required this.chartHeight,
    required this.minBarHeight,
    required this.barWidth,
  });

  static const double _countBarGap = 2;
  /// Line height reserved for the count above the bar (small label).
  static const double _countStripHeight = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    final inner =
        chartHeight - _countStripHeight - _countBarGap; // space for bar only
    final t = maxCount > 0 ? bin.count / maxCount : 0.0;
    final double barHeight = inner > 0
        ? ((inner * t).clamp(math.min(minBarHeight, inner), inner)).toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: chartHeight,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: _countStripHeight,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    '${bin.count}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: countStyle,
                  ),
                ),
              ),
              SizedBox(height: _countBarGap),
              Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(
                    math.max(barWidth / 2, 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bin.grade,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
