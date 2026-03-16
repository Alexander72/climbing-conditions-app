import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crag_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/condition_provider.dart';
import '../widgets/crag_card.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/condition.dart';
import 'crag_detail_screen.dart';
import 'add_crag_screen.dart';

class CragListScreen extends StatefulWidget {
  const CragListScreen({super.key});

  @override
  State<CragListScreen> createState() => _CragListScreenState();
}

class _CragListScreenState extends State<CragListScreen> {
  String? _selectedRockType;
  String? _selectedAspect;

  @override
  Widget build(BuildContext context) {
    return Consumer<CragProvider>(
      builder: (context, cragProvider, child) {
        if (cragProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cragProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${cragProvider.error}'),
                ElevatedButton(
                  onPressed: () => cragProvider.initialize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var crags = cragProvider.visibleCrags;
        final isDetailed = cragProvider.isDetailedZoom;
        final zoom = cragProvider.currentZoom;

        // Apply filters (only meaningful in detailed mode, but harmless otherwise)
        if (_selectedRockType != null) {
          crags = crags
              .where((c) => c.rockType.name == _selectedRockType)
              .toList();
        }
        if (_selectedAspect != null) {
          crags = crags
              .where((c) => c.aspect.name == _selectedAspect)
              .toList();
        }

        return Scaffold(
          body: Column(
            children: [
              _buildInfoBar(context, zoom, crags.length, cragProvider.isFetchingViewport),
              _buildFilters(context),
              Expanded(
                child: crags.isEmpty
                    ? _buildEmptyState(context, zoom)
                    : ListView.builder(
                        itemCount: crags.length,
                        itemBuilder: (context, index) {
                          final crag = crags[index];
                          final showSummary = !isDetailed || crag.isSummaryOnly;
                          return showSummary
                              ? CragCard(
                                  crag: crag,
                                  isSummaryOnly: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CragDetailScreen(crag: crag),
                                      ),
                                    );
                                  },
                                )
                              : FutureBuilder<Condition?>(
                                  future: _getConditionForCrag(context, crag),
                                  builder: (context, snapshot) {
                                    return CragCard(
                                      crag: crag,
                                      condition: snapshot.data,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CragDetailScreen(crag: crag),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddCragScreen(),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildInfoBar(
    BuildContext context,
    double zoom,
    int count,
    bool isFetching,
  ) {
    final String message;
    if (zoom < 7.0) {
      message = 'Zoom in on the map to discover crags';
    } else if (zoom <= 9.0) {
      message = count == 0
          ? 'Zoom in further to see crags in this area'
          : '$count crag${count == 1 ? '' : 's'} found — zoom in further to see conditions';
    } else {
      message = count == 0
          ? 'No crags found in this area'
          : 'Showing $count crag${count == 1 ? '' : 's'} with conditions';
    }

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          if (isFetching)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, double zoom) {
    final icon = zoom < 7.0 ? Icons.zoom_in : Icons.search_off;
    final label = zoom < 7.0
        ? 'Zoom in on the map\nto discover crags'
        : 'No crags in this area yet';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedRockType,
              decoration: const InputDecoration(
                labelText: 'Rock Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'sandstone', child: Text('Sandstone')),
                DropdownMenuItem(value: 'granite', child: Text('Granite')),
                DropdownMenuItem(value: 'limestone', child: Text('Limestone')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRockType = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:             DropdownButtonFormField<String>(
              initialValue: _selectedAspect,
              decoration: const InputDecoration(
                labelText: 'Aspect',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'north', child: Text('North')),
                DropdownMenuItem(value: 'south', child: Text('South')),
                DropdownMenuItem(value: 'east', child: Text('East')),
                DropdownMenuItem(value: 'west', child: Text('West')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAspect = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<Condition?> _getConditionForCrag(
    BuildContext context,
    Crag crag,
  ) async {
    final weatherProvider = context.read<WeatherProvider>();
    final conditionProvider = context.read<ConditionProvider>();

    try {
      final weather = await weatherProvider.fetchWeather(
        latitude: crag.latitude,
        longitude: crag.longitude,
      );
      final condition = await conditionProvider.calculateCondition(
        crag: crag,
        weather: weather,
      );
      return condition;
    } catch (e) {
      return null;
    }
  }
}
