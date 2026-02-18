import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/crag_provider.dart';
import '../../core/config.dart';
import '../../domain/entities/crag.dart';
import 'crag_detail_screen.dart';

class CragMapScreen extends StatefulWidget {
  const CragMapScreen({super.key});

  @override
  State<CragMapScreen> createState() => _CragMapScreenState();
}

class _CragMapScreenState extends State<CragMapScreen> {
  final MapController _mapController = MapController();

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

        final crags = cragProvider.crags;

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(
              AppConfig.defaultMapLatitude,
              AppConfig.defaultMapLongitude,
            ),
            initialZoom: AppConfig.defaultMapZoom,
            onTap: (tapPosition, point) {
              // Find nearest crag
              Crag? nearestCrag;
              double minDistance = double.infinity;

              for (final crag in crags) {
                final distance = _calculateDistance(
                  point.latitude,
                  point.longitude,
                  crag.latitude,
                  crag.longitude,
                );
                if (distance < minDistance && distance < 0.01) {
                  minDistance = distance;
                  nearestCrag = crag;
                }
              }

              if (nearestCrag != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CragDetailScreen(crag: nearestCrag!),
                  ),
                );
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.climbingapp.climbing_app',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: crags.map((crag) {
                return Marker(
                  point: LatLng(crag.latitude, crag.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CragDetailScreen(crag: crag),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.place,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    ) / 1000.0; // Convert to km
  }
}
