import 'package:flutter/material.dart';

class ReminderSettings {
  final bool enabled;
  final TimeOfDay timeOfDay;

  const ReminderSettings({
    required this.enabled,
    required this.timeOfDay,
  });

  ReminderSettings copyWith({
    bool? enabled,
    TimeOfDay? timeOfDay,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      timeOfDay: timeOfDay ?? this.timeOfDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'hour': timeOfDay.hour,
      'minute': timeOfDay.minute,
    };
  }

  factory ReminderSettings.fromMap(Map<String, dynamic> map) {
    final enabled = map['enabled'] as bool? ?? false;
    final hour = map['hour'] as int? ?? 21;
    final minute = map['minute'] as int? ?? 0;
    return ReminderSettings(
      enabled: enabled,
      timeOfDay: TimeOfDay(hour: hour, minute: minute),
    );
  }

  static ReminderSettings get defaults => ReminderSettings(
        enabled: false,
        timeOfDay: const TimeOfDay(hour: 21, minute: 0),
      );
}

