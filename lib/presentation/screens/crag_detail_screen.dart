import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../providers/condition_provider.dart';
import '../widgets/condition_card.dart';
import '../widgets/weather_info_card.dart';
import '../widgets/weather_chart.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/weather.dart';
import '../../domain/entities/condition.dart';

class CragDetailScreen extends StatefulWidget {
  final Crag crag;

  const CragDetailScreen({
    super.key,
    required this.crag,
  });

  @override
  State<CragDetailScreen> createState() => _CragDetailScreenState();
}

class _CragDetailScreenState extends State<CragDetailScreen> {
  Weather? _weather;
  Condition? _condition;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final weatherProvider = context.read<WeatherProvider>();
      final conditionProvider = context.read<ConditionProvider>();

      final weather = await weatherProvider.fetchWeather(
        latitude: widget.crag.latitude,
        longitude: widget.crag.longitude,
      );

      final condition = await conditionProvider.calculateCondition(
        crag: widget.crag,
        weather: weather,
      );

      setState(() {
        _weather = weather;
        _condition = condition;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.crag.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Crag info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.crag.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    label: Text(widget.crag.rockType.displayName),
                                    avatar: const Icon(Icons.landscape, size: 18),
                                  ),
                                  Chip(
                                    label: Text(widget.crag.aspect.displayName),
                                    avatar: const Icon(Icons.explore, size: 18),
                                  ),
                                  ...widget.crag.climbingTypes.map(
                                    (type) => Chip(
                                      label: Text(type.displayName),
                                      avatar: const Icon(Icons.arrow_upward, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.crag.description != null) ...[
                                const SizedBox(height: 8),
                                Text(widget.crag.description!),
                              ],
                              if (widget.crag.elevation != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Elevation: ${widget.crag.elevation!.toStringAsFixed(0)} m',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Condition card
                      if (_condition != null)
                        ConditionCard(condition: _condition!),
                      const SizedBox(height: 16),

                      // Weather info
                      if (_weather != null) ...[
                        WeatherInfoCard(weather: _weather!),
                        const SizedBox(height: 16),
                        WeatherChart(weather: _weather!, showForecast: false),
                        const SizedBox(height: 16),
                        WeatherChart(weather: _weather!, showForecast: true),
                      ],
                    ],
                  ),
                ),
    );
  }
}
