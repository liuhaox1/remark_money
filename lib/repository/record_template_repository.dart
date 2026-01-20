import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/record_template.dart';
import '../services/user_scope.dart';

class RecordTemplateRepository {
  static const _keyBase = 'record_templates_v1';
  String get _key => UserScope.key(_keyBase);
  static const _maxTemplates = 10;

  Future<List<RecordTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => RecordTemplate.fromMap(
              jsonDecode(e) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> saveTemplates(List<RecordTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final payload =
        templates.map((t) => jsonEncode(t.toMap())).toList(growable: false);
    await prefs.setStringList(_key, payload);
  }

  /// Insert or update a template, keeping most recent ones.
  Future<List<RecordTemplate>> upsertTemplate(RecordTemplate template) async {
    final list = await loadTemplates();
    final index = list.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      list[index] = template;
    } else {
      list.insert(0, template);
    }
    if (list.length > _maxTemplates) {
      list.removeRange(_maxTemplates, list.length);
    }
    await saveTemplates(list);
    return list;
  }

  /// Update last used timestamp for a template when user taps it.
  Future<List<RecordTemplate>> markUsed(String id) async {
    final list = await loadTemplates();
    final index = list.indexWhere((t) => t.id == id);
    if (index >= 0) {
      list[index] = list[index].copyWith(lastUsedAt: DateTime.now());
      await saveTemplates(list);
    }
    return list;
  }
}
