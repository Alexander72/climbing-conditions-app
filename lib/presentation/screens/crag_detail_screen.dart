import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crag_provider.dart';
import '../widgets/condition_card.dart';
import '../widgets/crag_route_stats_card.dart';
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
  late Crag _crag;
  Weather? _weather;
  Condition? _condition;
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _crag = widget.crag;
    _selectedDate = context.read<CragProvider>().selectedConditionDate;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cragProvider = context.read<CragProvider>();
      final data = await cragProvider.loadCragDetailFromBackend(widget.crag.id);

      if (!mounted) return;

      if (data == null) {
        debugPrint(
          '[CragDetailScreen] loadCragDetailFromBackend returned null for '
          'id=${widget.crag.id} — see [CragRepository] / [BackendApiClient] '
          'lines in the Flutter run console or DevTools logging.',
        );
        setState(() {
          _error = 'Failed to load crag detail (see debug console for [CragRepository] logs)';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _crag = data.crag;
        _weather = data.weather;
        _condition = data.crag.conditionForDate(_selectedDate);
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('[CragDetailScreen] _loadData threw: $e\n$st');
      if (!mounted) return;
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
        title: Text(_crag.name),
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _crag.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    label: Text(_crag.rockType.displayName),
                                    avatar: const Icon(Icons.landscape, size: 18),
                                  ),
                                  Chip(
                                    label: Text(_crag.aspect.displayName),
                                    avatar: const Icon(Icons.explore, size: 18),
                                  ),
                                  ..._crag.climbingTypes.map(
                                    (type) => Chip(
                                      label: Text(type.displayName),
                                      avatar: const Icon(Icons.arrow_upward, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                              if (_crag.description != null) ...[
                                const SizedBox(height: 8),
                                Text(_crag.description!),
                              ],
                              if (_crag.elevation != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Elevation: ${_crag.elevation!.toStringAsFixed(0)} m',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CragRouteStatsCard(stats: _crag.routeStats),
                      if (_crag.routeStats?.hasAnyData ?? false)
                        const SizedBox(height: 16),

                      if (_condition != null)
                        Column(
                          children: [
                            _buildDateSelector(),
                            const SizedBox(height: 8),
                            ConditionCard(condition: _condition!),
                          ],
                        ),
                      const SizedBox(height: 16),

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

  Widget _buildDateSelector() {
    final provider = context.read<CragProvider>();
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 13));
    final selectedLocal = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today),
        label: Text(
          'Conditions date: ${selectedLocal.day}/${selectedLocal.month}/${selectedLocal.year}',
        ),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedLocal,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (picked != null && context.mounted) {
            final selectedUtc = DateTime.utc(
              picked.year,
              picked.month,
              picked.day,
            );
            provider.setSelectedConditionDate(selectedUtc);
            setState(() {
              _selectedDate = provider.selectedConditionDate;
              _condition = _crag.conditionForDate(_selectedDate);
            });
          }
        },
      ),
    );
  }
}
