import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/crag_provider.dart';
import '../widgets/crag_marker.dart';
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
        final crags = cragProvider.visibleCrags;
        final isDetailed = cragProvider.isDetailedZoom;
        final markerSize = isDetailed ? 40.0 : 20.0;
        final selectedDate = cragProvider.selectedConditionDate;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  AppConfig.defaultMapLatitude,
                  AppConfig.defaultMapLongitude,
                ),
                initialZoom: AppConfig.defaultMapZoom,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  cursorKeyboardRotationOptions:
                      CursorKeyboardRotationOptions.disabled(),
                ),
                onMapEvent: (MapEvent event) {
                  if (event is MapEventMoveEnd ||
                      event is MapEventDoubleTapZoomEnd ||
                      event is MapEventFlingAnimationEnd) {
                    final bounds = _mapController.camera.visibleBounds;
                    final zoom = _mapController.camera.zoom;
                    context.read<CragProvider>().updateViewport(bounds, zoom);
                  }
                },
                onTap: (tapPosition, point) {
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
                        builder: (context) =>
                            CragDetailScreen(crag: nearestCrag!),
                      ),
                    );
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.climbingapp.climbing_app',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: crags.map((crag) {
                    return Marker(
                      point: LatLng(crag.latitude, crag.longitude),
                      width: markerSize,
                      height: markerSize,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CragDetailScreen(crag: crag),
                            ),
                          );
                        },
                        child: CragMarker(
                          crag: crag,
                          isDetailed: isDetailed,
                          selectedDate: selectedDate,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // Loading indicator while fetching crags for the viewport
            if (cragProvider.isFetchingViewport)
              const Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final firstDate = DateTime(now.year, now.month, now.day);
                  final lastDate = firstDate.add(const Duration(days: 13));
                  final selectedLocal = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                  );

                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${selectedLocal.day}/${selectedLocal.month}/${selectedLocal.year}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedLocal,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (picked != null && context.mounted) {
                        cragProvider.setSelectedConditionDate(
                          DateTime.utc(picked.year, picked.month, picked.day),
                        );
                      }
                    },
                  );
                },
              ),
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
        ) /
        1000.0;
  }
}

