import 'dart:math';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/budget.dart';
import '../models/account.dart';
import '../models/recurring_record.dart';
import '../models/record.dart';
import '../models/tag.dart';
import '../repository/repository_factory.dart';
import '../services/auth_service.dart';
import '../services/sync_outbox_service.dart';
import '../l10n/app_strings.dart';
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
      final token = await const AuthService().loadToken();
      final isLoggedIn = token != null && token.isNotEmpty;
      if (!isLoggedIn && _books.isNotEmpty) {
        throw Exception(AppStrings.guestSingleBookOnly);
      }
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
  Future<void> upgradeLocalBookToServer(
    String oldBookId,
    String newBookId, {
    bool queueUploadAllRecords = false,
  }) async {
    final index = _books.indexWhere((b) => b.id == oldBookId);
    if (index == -1) return;
    if (oldBookId == newBookId) return;
    try {
      final name = _books[index].name;
      _books[index] = Book(id: newBookId, name: name);
      if (_activeBookId == oldBookId) {
        _activeBookId = newBookId;
        await _repository.saveActiveBookId(newBookId);
      }
      await _repository.saveBooks(_books);

      // Migrate book-scoped data so the "upgraded" book keeps its local content/settings.
      if (RepositoryFactory.isUsingDatabase) {
        final db = await DatabaseHelper().database;
        await db.transaction((txn) async {
          // Records: move to new book and reset server sync meta (new server book => re-upload as new bills).
          await txn.update(
            Tables.records,
            {
              'book_id': newBookId,
              'server_id': null,
              'server_version': null,
            },
            where: 'book_id = ?',
            whereArgs: [oldBookId],
          );

          // Budgets: book_id is the primary key.
          await txn.update(
            Tables.budgets,
            {'book_id': newBookId},
            where: 'book_id = ?',
            whereArgs: [oldBookId],
          );

          // Tags / recurring records are scoped by book_id.
          await txn.update(
            Tables.tags,
            {'book_id': newBookId},
            where: 'book_id = ?',
            whereArgs: [oldBookId],
          );
          await txn.update(
            Tables.recurringRecords,
            {'book_id': newBookId},
            where: 'book_id = ?',
            whereArgs: [oldBookId],
          );

          // Accounts are scoped by book_id (v14+).
          try {
            await txn.update(
              Tables.accounts,
              {'book_id': newBookId},
              where: 'book_id = ?',
              whereArgs: [oldBookId],
            );
          } catch (_) {}

          // Any queued ops for the old book are now invalid; they must be rebuilt for the new book.
          await txn.delete(
            Tables.syncOutbox,
            where: 'book_id = ?',
            whereArgs: [oldBookId],
          );
          await txn.delete(
            Tables.syncOutbox,
            where: 'book_id = ?',
            whereArgs: [newBookId],
          );
        });
      } else {
        // SharedPreferences backend: migrate JSON payloads.
        final recordRepo = RepositoryFactory.createRecordRepository() as dynamic;
        final budgetRepo = RepositoryFactory.createBudgetRepository() as dynamic;
        final tagRepo = RepositoryFactory.createTagRepository() as dynamic;
        final accountRepo = RepositoryFactory.createAccountRepository() as dynamic;
        final recurringRepo =
            RepositoryFactory.createRecurringRecordRepository() as dynamic;

        try {
          final List<Record> list =
              (await recordRepo.loadRecords() as List).cast<Record>();
          final migrated = list.map<Record>((r) {
            if (r.bookId != oldBookId) return r;
            return Record(
              id: r.id,
              amount: r.amount,
              remark: r.remark,
              date: r.date,
              categoryKey: r.categoryKey,
              bookId: newBookId,
              accountId: r.accountId,
              direction: r.direction,
              includeInStats: r.includeInStats,
              pairId: r.pairId,
              serverId: null,
              serverVersion: null,
            );
          }).toList(growable: false);
          await recordRepo.saveRecords(migrated);
        } catch (e, stackTrace) {
          ErrorHandler.logError(
            'BookProvider.upgradeLocalBookToServer.migrateRecords',
            e,
            stackTrace,
          );
          rethrow;
        }

        try {
          final budget = await budgetRepo.loadBudget();
          final oldEntry = budget.entries[oldBookId];
          if (oldEntry != null) {
            final next = Map<String, BudgetEntry>.from(budget.entries);
            next.remove(oldBookId);
            next[newBookId] = oldEntry;
            await budgetRepo.saveBudget(Budget(entries: next));
          }
        } catch (_) {}

        try {
          final List<dynamic> list = await accountRepo.loadAccounts(bookId: oldBookId);
          final accounts = list.cast<Account>();
          if (accounts.isNotEmpty) {
            final migrated = accounts
                .map((a) => a.copyWith(bookId: newBookId))
                .toList(growable: false);
            await accountRepo.saveAccounts(bookId: newBookId, accounts: migrated);
            await accountRepo.saveAccounts(bookId: oldBookId, accounts: const <Account>[]);
          }
        } catch (_) {}

        try {
          final List<Tag> tagsOld =
              (await tagRepo.loadTags(bookId: oldBookId) as List).cast<Tag>();
          if (tagsOld.isNotEmpty) {
            await tagRepo.saveTagsForBook(
              newBookId,
              tagsOld
                  .map<Tag>((t) => t.copyWith(bookId: newBookId))
                  .toList(growable: false),
            );
            await tagRepo.saveTagsForBook(oldBookId, <Tag>[]);
          }
        } catch (_) {}

        try {
          final List<dynamic> plansRaw = await recurringRepo.loadPlans();
          final List<RecurringRecordPlan> plans =
              plansRaw.cast<RecurringRecordPlan>();
          final next = plans.map<RecurringRecordPlan>((p) {
            if (p.bookId != oldBookId) return p;
            return p.copyWith(bookId: newBookId);
          }).toList(growable: false);
          await recurringRepo.savePlans(next);
        } catch (_) {}

        // Clear any cached outbox for both old/new book ids.
        try {
          await SyncOutboxService.instance.clearBook(oldBookId);
          await SyncOutboxService.instance.clearBook(newBookId);
        } catch (_) {}
      }

        if (queueUploadAllRecords) {
          // Rebuild outbox so local records will be uploaded into the new server book.
          try {
            final recordRepo = RepositoryFactory.createRecordRepository() as dynamic;
            final List<Record> all =
                (await recordRepo.loadRecords() as List).cast<Record>();
            final target =
                all.where((r) => r.bookId == newBookId).toList(growable: false);
            for (final r in target) {
              await SyncOutboxService.instance.enqueueUpsert(r);
          }
        } catch (_) {}
      }

      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BookProvider.upgradeLocalBookToServer', e, stackTrace);
      rethrow;
    }
  }

  Future<void> reload() async {
    _books.clear();
    _activeBookId = null;
    _loaded = false;
    await load();
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
