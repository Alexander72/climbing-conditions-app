import 'package:flutter/material.dart';
import '../../domain/entities/weather.dart';

class WeatherInfoCard extends StatelessWidget {
  final Weather weather;

  const WeatherInfoCard({
    super.key,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Weather',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherItem(
                  context,
                  Icons.thermostat,
                  'Temperature',
                  '${weather.temperature.toStringAsFixed(1)}°C',
                ),
                _buildWeatherItem(
                  context,
                  Icons.water_drop,
                  'Humidity',
                  '${weather.humidity.toStringAsFixed(0)}%',
                ),
                _buildWeatherItem(
                  context,
                  Icons.air,
                  'Wind',
                  '${weather.windSpeed.toStringAsFixed(1)} m/s',
                ),
              ],
            ),
            if (weather.precipitation != null && weather.precipitation! > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Precipitation: ${weather.precipitation!.toStringAsFixed(1)} mm',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
