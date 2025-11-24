import 'package:flutter/material.dart';

import '../models/reminder_settings.dart';
import '../repository/reminder_repository.dart';

/// Stores reminder preferences for daily bookkeeping.
///
/// Note: current implementation only persists settings. Integrating with
/// system notifications (e.g. flutter_local_notifications) can be added later.
class ReminderProvider extends ChangeNotifier {
  ReminderProvider();

  final ReminderRepository _repository = ReminderRepository();

  ReminderSettings _settings = ReminderSettings.defaults;
  ReminderSettings get settings => _settings;

  bool get enabled => _settings.enabled;
  TimeOfDay get timeOfDay => _settings.timeOfDay;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _settings = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _settings = _settings.copyWith(enabled: value);
    await _repository.save(_settings);
    notifyListeners();
    // TODO: integrate scheduling / cancelling local notifications.
  }

  Future<void> setTime(TimeOfDay value) async {
    _settings = _settings.copyWith(timeOfDay: value);
    await _repository.save(_settings);
    notifyListeners();
    // TODO: reschedule local notifications when integrated.
  }
}

