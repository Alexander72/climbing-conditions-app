import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/weather.dart';

class WeatherChart extends StatelessWidget {
  final Weather weather;
  final bool showForecast;

  const WeatherChart({
    super.key,
    required this.weather,
    this.showForecast = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = showForecast
        ? _prepareForecastData()
        : _prepareHistoricalData();

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showForecast ? 'Forecast (14 days)' : 'Precipitation History (5 days)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: (data.length * 56).toDouble().clamp(320.0, 2000.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.isEmpty
                          ? 10
                          : (data.map((d) => d.precipitation ?? 0).reduce((a, b) => a > b ? a : b) + 5),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBorderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < data.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    data[index].label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 40,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}mm',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: item.precipitation ?? 0,
                              color: Colors.blue,
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ChartData> _prepareHistoricalData() {
    final now = DateTime.now();
    return weather.historical.map((h) {
      final daysDiff = now.difference(h.date).inDays;
      String label;
      if (daysDiff == 0) {
        label = 'Today';
      } else if (daysDiff == 1) {
        label = 'Yesterday';
      } else {
        label = '${daysDiff}d ago';
      }
      return _ChartData(
        label: label,
        precipitation: h.precipitation,
      );
    }).toList();
  }

  List<_ChartData> _prepareForecastData() {
    final now = DateTime.now().toUtc();
    final nowDay = DateTime.utc(now.year, now.month, now.day);
    return weather.forecast
        .where((f) {
          final d = f.date.toUtc();
          final forecastDay = DateTime.utc(d.year, d.month, d.day);
          return !forecastDay.isBefore(nowDay);
        })
        .map((f) {
      final d = f.date.toUtc();
      final forecastDay = DateTime.utc(d.year, d.month, d.day);
      return _ChartData(
        label: _formatForecastLabel(forecastDay),
        precipitation: f.precipitation,
      );
    }).toList();
  }

  String _formatForecastLabel(DateTime forecastDay) {
    final day = forecastDay.day.toString().padLeft(2, '0');
    final month = forecastDay.month.toString().padLeft(2, '0');
    return '$day.$month';
  }
}

class _ChartData {
  final String label;
  final double? precipitation;

  _ChartData({
    required this.label,
    this.precipitation,
  });
}
