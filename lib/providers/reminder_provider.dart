import 'package:flutter/material.dart';

import '../models/reminder_settings.dart';
import '../repository/repository_factory.dart';
import '../utils/error_handler.dart';

/// Stores reminder preferences for daily bookkeeping.
///
/// Note: current implementation only persists settings. Integrating with
/// system notifications (e.g. flutter_local_notifications) can be added later.
class ReminderProvider extends ChangeNotifier {
  ReminderProvider();

  // SharedPreferences / 数据库 两种实现共用相同方法签名
  final dynamic _repository = RepositoryFactory.createReminderRepository();

  ReminderSettings _settings = ReminderSettings.defaults;
  ReminderSettings get settings => _settings;

  bool get enabled => _settings.enabled;
  TimeOfDay get timeOfDay => _settings.timeOfDay;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _settings = await _repository.load();
      _loaded = true;
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('ReminderProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      _settings = _settings.copyWith(enabled: value);
      await _repository.save(_settings);
      notifyListeners();
      // TODO: integrate scheduling / cancelling local notifications.
    } catch (e, stackTrace) {
      ErrorHandler.logError('ReminderProvider.setEnabled', e, stackTrace);
      rethrow;
    }
  }

  Future<void> setTime(TimeOfDay value) async {
    try {
      _settings = _settings.copyWith(timeOfDay: value);
      await _repository.save(_settings);
      notifyListeners();
      // TODO: reschedule local notifications when integrated.
    } catch (e, stackTrace) {
      ErrorHandler.logError('ReminderProvider.setTime', e, stackTrace);
      rethrow;
    }
  }
}

