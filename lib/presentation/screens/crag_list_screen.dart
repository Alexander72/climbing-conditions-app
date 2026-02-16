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

        var crags = cragProvider.crags;

        // Apply filters
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
              _buildFilters(context),
              Expanded(
                child: ListView.builder(
                  itemCount: crags.length,
                  itemBuilder: (context, index) {
                    final crag = crags[index];
                    return FutureBuilder<Condition?>(
                      future: _getConditionForCrag(context, crag),
                      builder: (context, snapshot) {
                        return CragCard(
                          crag: crag,
                          condition: snapshot.data,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CragDetailScreen(crag: crag),
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
