import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/book.dart';
import '../services/user_scope.dart';

class BookRepository {
  static const _booksKeyBase = 'books_v1';
  static const _activeKeyBase = 'active_book_v1';

  String get _booksKey => UserScope.key(_booksKeyBase);
  String get _activeKey => UserScope.key(_activeKeyBase);

  Future<List<Book>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_booksKey);
    if (raw == null) {
      final defaults = _defaultBooks();
      await saveBooks(defaults);
      return defaults;
    }
    return raw.map((e) => Book.fromJson(e)).toList();
  }

  Future<void> saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = books.map((b) => b.toJson()).toList();
    await prefs.setStringList(_booksKey, payload);
  }

  Future<String> loadActiveBookId() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getString(_activeKey);
    if (active != null) return active;
    final books = await loadBooks();
    final id = books.first.id;
    await saveActiveBookId(id);
    return id;
  }

  Future<void> saveActiveBookId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  List<Book> _defaultBooks() {
    return const [
      Book(id: 'default-book', name: AppStrings.defaultBook),
    ];
  }
}
