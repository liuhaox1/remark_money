import 'dart:math';

import 'package:flutter/material.dart';

import '../models/recurring_record.dart';
import '../repository/repository_factory.dart';
import '../utils/error_handler.dart';

class RecurringRecordProvider extends ChangeNotifier {
  RecurringRecordProvider();

  final dynamic _repo = RepositoryFactory.createRecurringRecordRepository();
  final Random _random = Random();

  final List<RecurringRecordPlan> _plans = <RecurringRecordPlan>[];
  List<RecurringRecordPlan> get plans => List.unmodifiable(_plans);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final List<RecurringRecordPlan> list =
          (await _repo.loadPlans()).cast<RecurringRecordPlan>();
      _plans
        ..clear()
        ..addAll(list);
      _loaded = true;
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecurringRecordProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  Future<void> reload() async {
    try {
      final List<RecurringRecordPlan> list =
          (await _repo.loadPlans()).cast<RecurringRecordPlan>();
      _plans
        ..clear()
        ..addAll(list);
      _loaded = true;
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecurringRecordProvider.reload', e, stackTrace);
      rethrow;
    }
  }

  Future<RecurringRecordPlan> upsert(RecurringRecordPlan plan) async {
    try {
      final List<RecurringRecordPlan> list =
          (await _repo.upsert(plan)).cast<RecurringRecordPlan>();
      _plans
        ..clear()
        ..addAll(list);
      notifyListeners();
      return plan;
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecurringRecordProvider.upsert', e, stackTrace);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    try {
      final List<RecurringRecordPlan> list =
          (await _repo.remove(id)).cast<RecurringRecordPlan>();
      _plans
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecurringRecordProvider.remove', e, stackTrace);
      rethrow;
    }
  }

  Future<void> toggleEnabled(RecurringRecordPlan plan, bool enabled) async {
    await upsert(plan.copyWith(enabled: enabled));
  }

  String generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}

