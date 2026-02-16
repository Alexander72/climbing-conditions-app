import 'package:flutter/foundation.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/weather.dart';
import '../../domain/services/condition_calculator.dart';
import '../../data/database/app_database.dart';
import '../../data/models/condition_model.dart';

class ConditionProvider with ChangeNotifier {
  final ConditionCalculator _calculator;
  final AppDatabase _database;
  final Map<String, Condition> _conditionCache = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errors = {};

  ConditionProvider({
    ConditionCalculator? calculator,
    AppDatabase? database,
  })  : _calculator = calculator ?? ConditionCalculator(),
        _database = database ?? AppDatabase();

  Condition? getCondition(String cragId) {
    return _conditionCache[cragId];
  }

  bool isLoading(String cragId) {
    return _loadingStates[cragId] ?? false;
  }

  String? getError(String cragId) {
    return _errors[cragId];
  }

  Future<Condition> calculateCondition({
    required Crag crag,
    required Weather weather,
  }) async {
    _loadingStates[crag.id] = true;
    _errors[crag.id] = null;
    notifyListeners();

    try {
      final condition = _calculator.calculateCondition(
        crag: crag,
        weather: weather,
      );

      _conditionCache[crag.id] = condition;

      // Save to history
      final conditionModel = ConditionModel.fromEntity(condition);
      await _database.saveConditionHistory(
        cragId: crag.id,
        condition: conditionModel,
      );

      return condition;
    } catch (e) {
      _errors[crag.id] = 'Failed to calculate condition: $e';
      rethrow;
    } finally {
      _loadingStates[crag.id] = false;
      notifyListeners();
    }
  }

  Future<List<Condition>> getConditionHistory(String cragId) async {
    try {
      final models = await _database.getConditionHistory(cragId);
      return models.map((m) => m.toEntity()).toList();
    } catch (e) {
      return [];
    }
  }

  void clearCache() {
    _conditionCache.clear();
    _errors.clear();
    notifyListeners();
  }
}
