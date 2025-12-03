import 'dart:math';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../repository/repository_factory.dart';

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
    final list = await _repository.loadBooks();
    _books
      ..clear()
      ..addAll(list);
    _activeBookId = await _repository.loadActiveBookId();
    _loaded = true;
    notifyListeners();
  }

  Future<void> selectBook(String id) async {
    if (_activeBookId == id) return;
    _activeBookId = id;
    await _repository.saveActiveBookId(id);
    notifyListeners();
  }

  Future<void> addBook(String name) async {
    final id = _generateId();
    final book = Book(id: id, name: name);
    _books.add(book);
    await _repository.saveBooks(_books);
    await selectBook(id);
  }

  Future<void> renameBook(String id, String name) async {
    final index = _books.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _books[index] = _books[index].copyWith(name: name);
    await _repository.saveBooks(_books);
    notifyListeners();
  }

  Future<void> deleteBook(String id) async {
    if (_books.length <= 1) return;
    _books.removeWhere((book) => book.id == id);
    if (_activeBookId == id) {
      _activeBookId = _books.first.id;
      await _repository.saveActiveBookId(_activeBookId!);
    }
    await _repository.saveBooks(_books);
    notifyListeners();
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
