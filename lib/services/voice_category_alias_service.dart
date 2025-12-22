import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_settings_service.dart';

class VoiceCategoryAliasService {
  static final VoiceCategoryAliasService instance = VoiceCategoryAliasService._();
  VoiceCategoryAliasService._();

  static String _keyForBook(String bookId) => 'voice_category_aliases_$bookId';

  String normalizePhrase(String phrase) {
    return phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<Map<String, String>> loadAliases(String bookId) async {
    final raw = await AppSettingsService.instance.getString(_keyForBook(bookId));
    if (raw == null || raw.trim().isEmpty) return <String, String>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('[VoiceCategoryAliasService] loadAliases failed: $e');
      return <String, String>{};
    }
  }

  Future<void> saveAlias(
    String bookId, {
    required String phrase,
    required String categoryKey,
  }) async {
    final normalized = normalizePhrase(phrase);
    if (normalized.isEmpty) return;
    final aliases = await loadAliases(bookId);
    final next = <String, String>{...aliases, normalized: categoryKey};
    await AppSettingsService.instance.setString(
      _keyForBook(bookId),
      json.encode(next),
    );
  }

  Future<String?> matchAlias(
    String bookId, {
    required String phrase,
  }) async {
    final normalized = normalizePhrase(phrase);
    if (normalized.isEmpty) return null;
    final aliases = await loadAliases(bookId);
    return aliases[normalized];
  }
}

