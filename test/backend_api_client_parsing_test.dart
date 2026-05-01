import 'package:flutter_test/flutter_test.dart';
import 'package:climbing_app/data/datasources/backend_api_client.dart';
import 'package:climbing_app/data/models/crag_model.dart';

void main() {
  test('parseMergedWeatherJson keeps forecast up to 14 days', () {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'current': {
        'temp': 12.0,
        'humidity': 55.0,
        'wind_speed': 3.0,
        'dt': now.millisecondsSinceEpoch ~/ 1000,
      },
      'daily': List.generate(
        20,
        (index) => {
          'dt': now.add(Duration(days: index)).millisecondsSinceEpoch ~/ 1000,
          'temp': {'day': 10 + index},
          'wind_speed': 2.0,
          'rain': 0.0,
        },
      ),
    };

    final weather = parseMergedWeatherJson(payload);
    expect(weather.forecast.length, 14);
  });

  test('parseMergedWeatherJson pads daily forecast to 14 days', () {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'current': {
        'temp': 12.0,
        'humidity': 55.0,
        'wind_speed': 3.0,
        'dt': now.millisecondsSinceEpoch ~/ 1000,
      },
      'daily': List.generate(
        7,
        (index) => {
          'dt': now.add(Duration(days: index)).millisecondsSinceEpoch ~/ 1000,
          'temp': {'day': 10 + index},
          'wind_speed': 2.0,
          'rain': 0.0,
        },
      ),
    };

    final weather = parseMergedWeatherJson(payload);
    expect(weather.forecast.length, 14);
    expect(weather.forecast[13].dt, isNotNull);
  });

  test('CragModel parses conditionForecast entries', () {
    final model = CragModel.fromJson({
      'id': 'test',
      'name': 'Test Crag',
      'latitude': 1.0,
      'longitude': 2.0,
      'aspect': 'unknown',
      'rockType': 'limestone',
      'climbingTypes': ['sport'],
      'source': 'fetched',
      'isSummaryOnly': false,
      'conditionForecast': [
        {
          'date': '2026-05-01',
          'score': 70,
          'recommendation': 'good',
          'factors': ['dry rock'],
          'lastUpdated': 1700000000,
        }
      ],
    });

    final entity = model.toEntity();
    expect(entity.conditionForecast.length, 1);
    expect(entity.conditionForecast.first.score, 70);
  });
}
