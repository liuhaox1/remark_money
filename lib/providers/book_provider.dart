import 'dart:math';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../repository/repository_factory.dart';
import '../utils/error_handler.dart';

class BookProvider extends ChangeNotifier {
  BookProvider();

  // 这里返回的可能是 SharedPreferences 版本，也可能是数据库版本
  // 两者都实现了相同的方法签名，使用 dynamic 即可
  final dynamic _repository = RepositoryFactory.createBookRepository();
  final Random _random = Random();

  final List<Book> _books = [];
  List<Book> get books => List.unmodifiable(_books);

  String? _activeBookId;
  String get activeBookId =>
      _activeBookId ?? (_books.isNotEmpty ? _books.first.id : 'default-book');

  Book? get activeBook {
    if (_books.isEmpty) return null;
    return _books.firstWhere(
      (b) => b.id == activeBookId,
      orElse: () => _books.first,
    );
  }

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final list = await _repository.loadBooks();
      _books
        ..clear()
        ..addAll(list);
      _activeBookId = await _repository.loadActiveBookId();
      _loaded = true;
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  Future<void> selectBook(String id) async {
    if (_activeBookId == id) return;
    try {
      _activeBookId = id;
      await _repository.saveActiveBookId(id);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.selectBook', e, stackTrace);
      rethrow;
    }
  }

  Future<void> addBook(String name) async {
    try {
      final id = _generateId();
      final book = Book(id: id, name: name);
      _books.add(book);
      await _repository.saveBooks(_books);
      await selectBook(id);
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.addBook', e, stackTrace);
      rethrow;
    }
  }

  Future<void> renameBook(String id, String name) async {
    final index = _books.indexWhere((b) => b.id == id);
    if (index == -1) return;
    try {
      _books[index] = _books[index].copyWith(name: name);
      await _repository.saveBooks(_books);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.renameBook', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    if (_books.length <= 1) return;
    try {
      _books.removeWhere((book) => book.id == id);
      if (_activeBookId == id) {
        _activeBookId = _books.first.id;
        await _repository.saveActiveBookId(_activeBookId!);
      }
      await _repository.saveBooks(_books);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.deleteBook', e, stackTrace);
      rethrow;
    }
  }

  /// 添加一个服务器端多人账本（id 为服务器自增ID的字符串）
  Future<void> addServerBook(String id, String name) async {
    if (_books.any((b) => b.id == id)) return;
    try {
      final book = Book(id: id, name: name);
      _books.add(book);
      await _repository.saveBooks(_books);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.addServerBook', e, stackTrace);
      rethrow;
    }
  }

  /// 将本地账本升级为服务器多人账本（迁移记录 bookId 并替换本地Book id）
  Future<void> upgradeLocalBookToServer(String oldBookId, String newBookId) async {
    final index = _books.indexWhere((b) => b.id == oldBookId);
    if (index == -1) return;
    try {
      final name = _books[index].name;
      _books[index] = Book(id: newBookId, name: name);
      if (_activeBookId == oldBookId) {
        _activeBookId = newBookId;
        await _repository.saveActiveBookId(newBookId);
      }
      await _repository.saveBooks(_books);

      if (RepositoryFactory.isUsingDatabase) {
        final repo = RepositoryFactory.createRecordRepository() as dynamic;
        try {
          await repo.migrateBookId(oldBookId, newBookId);
        } catch (_) {}
      }

      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.upgradeLocalBookToServer', e, stackTrace);
      rethrow;
    }
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
