import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to track and persist API response times per model.
/// Stores the last 100 response times for each model and calculates averages.
class SpeedTrackingService {
  /// Returns the singleton instance of SpeedTrackingService.
  factory SpeedTrackingService() => _instance;
  SpeedTrackingService._internal();
  final Logger _log = getLogger('SpeedTrackingService');
  static const String _storageKey = 'model_speed_tracking';
  static const int _maxValuesPerModel = 100;

  // Singleton instance
  static final SpeedTrackingService _instance =
      SpeedTrackingService._internal();

  // In-memory cache
  Map<String, List<double>>? _cache;

  // Stream to notify listeners when stats are updated
  final _statsUpdatedController = StreamController<void>.broadcast();

  /// Stream that emits when speed statistics are updated.
  ///
  /// Listeners can subscribe to this stream to be notified whenever new
  /// timing data is recorded for any model.
  Stream<void> get statsUpdatedStream => _statsUpdatedController.stream;

  /// Loads timing data from SharedPreferences.
  Future<Map<String, List<double>>> _loadData() async {
    if (_cache != null) return _cache!;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      _cache = {};
      return _cache!;
    }

    try {
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      _cache = decoded.map((key, value) {
        final list = (value as List).map((e) => (e as num).toDouble()).toList();
        return MapEntry(key, list);
      });
      return _cache!;
    } on Exception catch (e) {
      _log.warning('Error loading speed tracking data: $e');
      _cache = {};
      return _cache!;
    }
  }

  /// Saves timing data to SharedPreferences.
  Future<void> _saveData(Map<String, List<double>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(data);
    await prefs.setString(_storageKey, jsonString);
    _cache = data;
  }

  /// Records a response time for the specified model.
  /// Keeps only the last [_maxValuesPerModel] values.
  Future<void> recordTime(String model, double seconds) async {
    final data = await _loadData();

    if (!data.containsKey(model)) {
      data[model] = [];
    }

    data[model]!.add(seconds);

    // Keep only the last N values
    if (data[model]!.length > _maxValuesPerModel) {
      data[model] = data[model]!.sublist(
        data[model]!.length - _maxValuesPerModel,
      );
    }

    await _saveData(data);

    // Notify listeners that stats have been updated
    _statsUpdatedController.add(null);
  }

  /// Gets the average response time for the specified model.
  /// Returns null if no data is available.
  Future<double?> getAverageTime(String model) async {
    final data = await _loadData();
    final times = data[model];

    if (times == null || times.isEmpty) {
      return null;
    }

    final sum = times.reduce((a, b) => a + b);
    return sum / times.length;
  }

  /// Gets the number of recorded calls for the specified model.
  Future<int> getCallCount(String model) async {
    final data = await _loadData();
    return data[model]?.length ?? 0;
  }

  /// Gets statistics for all models.
  /// Returns a map of model name to (average time, call count).
  Future<Map<String, ({double? avg, int count})>> getAllStats() async {
    final data = await _loadData();
    final stats = <String, ({double? avg, int count})>{};

    for (final entry in data.entries) {
      final times = entry.value;
      if (times.isEmpty) {
        stats[entry.key] = (avg: null, count: 0);
      } else {
        final sum = times.reduce((a, b) => a + b);
        stats[entry.key] = (avg: sum / times.length, count: times.length);
      }
    }

    return stats;
  }

  /// Clears all timing data for a specific model.
  Future<void> clearModel(String model) async {
    final data = await _loadData();
    data.remove(model);
    await _saveData(data);
  }

  /// Clears all timing data.
  Future<void> clearAll() async {
    await _saveData({});
  }
}
