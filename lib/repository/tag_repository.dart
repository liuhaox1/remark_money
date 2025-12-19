import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tag.dart';

class TagRepository {
  static const String _tagsKey = 'tags_v1';
  static const String _recordTagsKey = 'record_tags_v1';

  Future<List<Tag>> loadTags({required String bookId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tagsKey) ?? const <String>[];
    final tags = raw.map((s) => Tag.fromJson(s)).toList();
    tags.removeWhere((t) => t.bookId != bookId);
    tags.sort((a, b) {
      final bySort = a.sortOrder.compareTo(b.sortOrder);
      if (bySort != 0) return bySort;
      final ac = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bc = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return ac.compareTo(bc);
    });
    return tags;
  }

  Future<void> _saveAllTags(List<Tag> allTags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tagsKey, allTags.map((t) => t.toJson()).toList());
  }

  Future<List<Tag>> _loadAllTags() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tagsKey) ?? const <String>[];
    return raw.map((s) => Tag.fromJson(s)).toList();
  }

  Future<List<Tag>> addTag(Tag tag) async {
    final all = await _loadAllTags();
    all.removeWhere((t) => t.id == tag.id);
    all.add(tag);
    await _saveAllTags(all);
    return loadTags(bookId: tag.bookId);
  }

  Future<List<Tag>> updateTag(Tag tag) async {
    final all = await _loadAllTags();
    final idx = all.indexWhere((t) => t.id == tag.id);
    if (idx != -1) {
      all[idx] = tag;
      await _saveAllTags(all);
    }
    return loadTags(bookId: tag.bookId);
  }

  Future<List<Tag>> deleteTag(String id, {required String bookId}) async {
    final all = await _loadAllTags();
    all.removeWhere((t) => t.id == id);
    await _saveAllTags(all);

    final mapping = await _loadRecordTagsMapping();
    mapping.forEach((recordId, ids) => ids.removeWhere((tid) => tid == id));
    await _saveRecordTagsMapping(mapping);

    return loadTags(bookId: bookId);
  }

  Future<Map<String, List<String>>> _loadRecordTagsMapping() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordTagsKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
    );
  }

  Future<void> _saveRecordTagsMapping(Map<String, List<String>> mapping) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordTagsKey, json.encode(mapping));
  }

  Future<List<String>> getTagIdsForRecord(String recordId) async {
    final mapping = await _loadRecordTagsMapping();
    return List<String>.from(mapping[recordId] ?? const <String>[]);
  }

  Future<void> setTagsForRecord(String recordId, List<String> tagIds) async {
    final mapping = await _loadRecordTagsMapping();
    mapping[recordId] = List<String>.from(tagIds.toSet());
    await _saveRecordTagsMapping(mapping);
  }

  Future<void> deleteLinksForRecord(String recordId) async {
    final mapping = await _loadRecordTagsMapping();
    mapping.remove(recordId);
    await _saveRecordTagsMapping(mapping);
  }
}

