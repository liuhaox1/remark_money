import 'package:flutter/material.dart';

import '../models/category.dart';
import '../repository/category_repository.dart';
import '../repository/repository_factory.dart';
import '../services/category_delete_queue.dart';
import '../services/meta_sync_notifier.dart';
import '../utils/error_handler.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider();

  // Use the repository selected by RepositoryFactory for the default book.
  final dynamic _repo = RepositoryFactory.createCategoryRepository();
  // Use shared-prefs cache for server books to avoid cross-book overwrites.
  final CategoryRepository _cacheRepo = CategoryRepository();

  final List<Category> _categories = <Category>[];
  final Set<String> _loadedBooks = <String>{};
  String? _activeBookId;

  List<Category> get categories => List.unmodifiable(_categories);

  bool get loaded =>
      _activeBookId != null && _loadedBooks.contains(_activeBookId);

  bool _useCacheForBook(String bookId) => int.tryParse(bookId) != null;

  String _normalizeBookId(String? bookId) {
    final id = (bookId ?? '').trim();
    return id.isEmpty ? 'default-book' : id;
  }

  bool isLoadedForBook(String bookId) {
    final normalized = _normalizeBookId(bookId);
    return _activeBookId == normalized && _loadedBooks.contains(normalized);
  }

  bool hasCategoriesForBook(String bookId) {
    return isLoadedForBook(bookId) && _categories.isNotEmpty;
  }

  Category _sanitize(Category c) =>
      c.copyWith(name: CategoryRepository.sanitizeCategoryName(c.key, c.name));

  void replaceFromCloud(List<Category> categories) {
    replaceFromCloudForBook('default-book', categories);
  }

  void replaceFromCloudForBook(String bookId, List<Category> categories) {
    final normalized = _normalizeBookId(bookId);
    _categories
      ..clear()
      ..addAll(categories.map(_sanitize));
    _activeBookId = normalized;
    _loadedBooks.add(normalized);
    if (_useCacheForBook(normalized)) {
      _cacheRepo.saveCategories(categories, bookId: normalized);
    } else {
      _repo.saveCategories(categories, bookId: normalized);
      _cacheRepo.saveCategories(categories, bookId: normalized);
    }
    notifyListeners();
  }

  Future<void> load() async {
    await loadForBook('default-book');
  }

  Future<void> loadForBook(String bookId) async {
    final normalized = _normalizeBookId(bookId);
    if (_activeBookId == normalized && _loadedBooks.contains(normalized)) {
      return;
    }

    try {
      final List<Category> list = _useCacheForBook(normalized)
          ? (await _cacheRepo.loadCategories(
                  bookId: normalized, allowDefault: false))
              .cast<Category>()
          : (await _repo.loadCategories(bookId: normalized)).cast<Category>();
      _categories
        ..clear()
        ..addAll(list.map(_sanitize));
      _activeBookId = normalized;
      _loadedBooks.add(normalized);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('CategoryProvider.loadForBook', e, stackTrace);
      _loadedBooks.remove(normalized);
      rethrow;
    }
  }

  Future<void> reload() async {
    await reloadForBook('default-book');
  }

  Future<void> reloadForBook(String bookId) async {
    final normalized = _normalizeBookId(bookId);
    try {
      final List<Category> list = _useCacheForBook(normalized)
          ? (await _cacheRepo.loadCategories(
                  bookId: normalized, allowDefault: false))
              .cast<Category>()
          : (await _repo.loadCategories(bookId: normalized)).cast<Category>();
      _categories
        ..clear()
        ..addAll(list.map(_sanitize));
      _activeBookId = normalized;
      _loadedBooks.add(normalized);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('CategoryProvider.reloadForBook', e, stackTrace);
      _loadedBooks.remove(normalized);
      rethrow;
    }
  }

  Future<void> addCategory(Category c) async {
    try {
      final bookId = _normalizeBookId(_activeBookId);
      final List<Category> list = _useCacheForBook(bookId)
          ? (await _cacheRepo.add(c, bookId: bookId)).cast<Category>()
          : (await _repo.add(c, bookId: bookId)).cast<Category>();
      await _cacheRepo.saveCategories(list, bookId: bookId);
      _categories
        ..clear()
        ..addAll(list.map(_sanitize));
      MetaSyncNotifier.instance.notifyCategoriesChanged(bookId);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('CategoryProvider.addCategory', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCategory(String key) async {
    try {
      final bookId = _normalizeBookId(_activeBookId);
      final List<Category> list = _useCacheForBook(bookId)
          ? (await _cacheRepo.delete(key, bookId: bookId)).cast<Category>()
          : (await _repo.delete(key, bookId: bookId)).cast<Category>();
      await CategoryDeleteQueue.instance.enqueue(bookId, key);
      await _cacheRepo.saveCategories(list, bookId: bookId);
      _categories
        ..clear()
        ..addAll(list.map(_sanitize));
      MetaSyncNotifier.instance.notifyCategoriesChanged(bookId);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('CategoryProvider.deleteCategory', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      final bookId = _normalizeBookId(_activeBookId);
      final List<Category> list = _useCacheForBook(bookId)
          ? (await _cacheRepo.update(category, bookId: bookId)).cast<Category>()
          : (await _repo.update(category, bookId: bookId)).cast<Category>();
      await _cacheRepo.saveCategories(list, bookId: bookId);
      _categories
        ..clear()
        ..addAll(list.map(_sanitize));
      MetaSyncNotifier.instance.notifyCategoriesChanged(bookId);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('CategoryProvider.updateCategory', e, stackTrace);
      rethrow;
    }
  }
}
