import 'dart:math';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../models/tag.dart';
import '../repository/repository_factory.dart';
import '../services/tag_delete_queue.dart';
import '../services/sync_outbox_service.dart';
import '../services/meta_sync_notifier.dart';
import '../utils/error_handler.dart';

class TagProvider extends ChangeNotifier {
  TagProvider();

  final dynamic _repo = RepositoryFactory.createTagRepository();
  final Random _random = Random();

  String? _loadedBookId;
  final List<Tag> _tags = [];
  List<Tag> get tags => List.unmodifiable(_tags);

  final Map<String, List<String>> _recordTagIdsCache = {};

  bool _loading = false;
  bool get loading => _loading;

  void replaceFromCloud(String bookId, List<Tag> tags) {
    _loadedBookId = bookId;
    _tags
      ..clear()
      ..addAll(tags);
    _recordTagIdsCache.clear();
    _loading = false;
    notifyListeners();
  }

  Future<void> loadForBook(String bookId, {bool force = false}) async {
    if (!force && _loadedBookId == bookId) return;
    _loading = true;
    notifyListeners();
    try {
      final List<Tag> list = (await _repo.loadTags(bookId: bookId)).cast<Tag>();
      _loadedBookId = bookId;
      _tags
        ..clear()
        ..addAll(list);
      _recordTagIdsCache.clear();
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.loadForBook', e, stackTrace);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<Tag> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return tags;
    return _tags.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  Future<Tag> createTag({
    required String bookId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag name is empty');
    }
    final exists = _tags.any(
      (t) => t.bookId == bookId && t.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      return _tags.firstWhere(
        (t) => t.bookId == bookId && t.name.toLowerCase() == trimmed.toLowerCase(),
      );
    }

    final id = _generateId();
    final now = DateTime.now();
    final colorValue = _pickNextColorValue();
    final tag = Tag(
      id: id,
      bookId: bookId,
      name: trimmed,
      colorValue: colorValue,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final List<Tag> list = (await _repo.addTag(tag)).cast<Tag>();
      _loadedBookId = bookId;
      _tags
        ..clear()
        ..addAll(list);
      MetaSyncNotifier.instance.notifyTagsChanged(bookId);
      notifyListeners();
      return tag;
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.createTag', e, stackTrace);
      rethrow;
    }
  }

  Future<void> renameTag(Tag tag, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == tag.name) return;
    final dup = _tags.any(
      (t) =>
          t.bookId == tag.bookId &&
          t.id != tag.id &&
          t.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (dup) return;

    final updated = tag.copyWith(name: trimmed, updatedAt: DateTime.now());
    try {
      final List<Tag> list = (await _repo.updateTag(updated)).cast<Tag>();
      _tags
        ..clear()
        ..addAll(list);
      MetaSyncNotifier.instance.notifyTagsChanged(tag.bookId);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.renameTag', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTag(Tag tag) async {
    try {
      final List<Tag> list =
          (await _repo.deleteTag(tag.id, bookId: tag.bookId)).cast<Tag>();
      await TagDeleteQueue.instance.enqueue(bookId: tag.bookId, tagId: tag.id);
      _tags
        ..clear()
        ..addAll(list);
      _recordTagIdsCache.removeWhere((_, ids) => ids.contains(tag.id));
      MetaSyncNotifier.instance.notifyTagsChanged(tag.bookId);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.deleteTag', e, stackTrace);
      rethrow;
    }
  }

  Future<List<String>> getTagIdsForRecord(String recordId) async {
    final cached = _recordTagIdsCache[recordId];
    if (cached != null) return List<String>.from(cached);
    try {
      final List<String> ids =
          (await _repo.getTagIdsForRecord(recordId)).cast<String>();
      _recordTagIdsCache[recordId] = List<String>.from(ids);
      return ids;
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.getTagIdsForRecord', e, stackTrace);
      rethrow;
    }
  }

  Future<void> setTagsForRecord(
    String recordId,
    List<String> tagIds, {
    Record? record,
  }) async {
    try {
      await _repo.setTagsForRecord(recordId, tagIds);
      _recordTagIdsCache[recordId] = List<String>.from(tagIds.toSet());
      if (record != null && record.serverId != null) {
        await SyncOutboxService.instance.enqueueUpsert(record);
      }
      if (record != null) {
        MetaSyncNotifier.instance.notifyTagsChanged(record.bookId);
      }
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.setTagsForRecord', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteLinksForRecord(
    String recordId, {
    Record? record,
  }) async {
    try {
      await _repo.deleteLinksForRecord(recordId);
      _recordTagIdsCache.remove(recordId);
      if (record != null && record.serverId != null) {
        await SyncOutboxService.instance.enqueueUpsert(record);
      }
      if (record != null) {
        MetaSyncNotifier.instance.notifyTagsChanged(record.bookId);
      }
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.deleteLinksForRecord', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, List<Tag>>> loadTagsForRecords(List<String> recordIds) async {
    if (recordIds.isEmpty) return <String, List<Tag>>{};
    try {
      if (RepositoryFactory.isUsingDatabase &&
          _repo.runtimeType.toString().contains('TagRepositoryDb')) {
        final raw = await _repo.loadTagsForRecords(recordIds);
        final map = (raw as Map).map(
          (k, v) => MapEntry(k as String, (v as List).cast<Tag>()),
        );
        for (final entry in map.entries) {
          _recordTagIdsCache[entry.key] = entry.value.map((t) => t.id).toList();
        }
        return map;
      }

      final result = <String, List<Tag>>{};
      for (final recordId in recordIds) {
        final ids = await getTagIdsForRecord(recordId);
        final tags = ids
            .map((id) => _tags.firstWhere(
                  (t) => t.id == id,
                  orElse: () => Tag(id: id, bookId: _loadedBookId ?? '', name: ''),
                ))
            .where((t) => t.name.isNotEmpty)
            .toList();
        result[recordId] = tags;
      }
      return result;
    } catch (e, stackTrace) {
      ErrorHandler.logError('TagProvider.loadTagsForRecords', e, stackTrace);
      rethrow;
    }
  }

  int? _pickNextColorValue() {
    final used = _tags.map((t) => t.colorValue).whereType<int>().toSet();
    for (final c in TagPalette.defaultColors) {
      if (!used.contains(c)) return c;
    }
    if (TagPalette.defaultColors.isEmpty) return null;
    return TagPalette.defaultColors[_random.nextInt(TagPalette.defaultColors.length)];
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
