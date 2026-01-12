import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/category.dart' as app_model;
import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';
import '../repository/repository_factory.dart';

class QaSeedOptions {
  const QaSeedOptions({
    this.bookId = 'qa-book',
    this.bookName = 'QA测试账本',
    this.activateBook = true,
    this.wipeExistingRecordsInBook = false,
    this.recordCount = 300,
    this.daysBack = 180,
    this.tagCount = 12,
    this.randomSeed = 20260105,
  });

  final String bookId;
  final String bookName;
  final bool activateBook;
  final bool wipeExistingRecordsInBook;
  final int recordCount;
  final int daysBack;
  final int tagCount;
  final int randomSeed;
}

class QaSeedReport {
  const QaSeedReport({
    required this.bookId,
    required this.createdAccounts,
    required this.createdTags,
    required this.createdRecords,
  });

  final String bookId;
  final int createdAccounts;
  final int createdTags;
  final int createdRecords;
}

class QaSeedService {
  QaSeedService._();

  static Future<QaSeedReport> seed(
    BuildContext context, {
    QaSeedOptions options = const QaSeedOptions(),
  }) async {
    final bookProvider = context.read<BookProvider>();
    final accountProvider = context.read<AccountProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final recordProvider = context.read<RecordProvider>();
    final tagProvider = context.read<TagProvider>();

    if (!bookProvider.loaded) await bookProvider.load();
    if (!accountProvider.loaded) await accountProvider.load();
    if (!categoryProvider.loaded) {
      await categoryProvider.loadForBook(bookProvider.activeBookId);
    }
    if (!recordProvider.loaded) await recordProvider.load();

    // 1) Ensure QA book exists.
    if (!bookProvider.books.any((b) => b.id == options.bookId)) {
      await bookProvider.addServerBook(options.bookId, options.bookName);
    }
    if (options.activateBook) {
      await bookProvider.selectBook(options.bookId);
    }

    await categoryProvider.loadForBook(options.bookId);
    await tagProvider.loadForBook(options.bookId);

    // 2) Accounts: default wallet + a few representative types.
    await accountProvider.ensureDefaultWallet(bookId: options.bookId);
    final createdAccounts = await _ensureQaAccounts(
      accountProvider,
      bookId: options.bookId,
    );

    // 3) Optionally wipe existing records in QA book (QA-only).
    if (options.wipeExistingRecordsInBook) {
      await _wipeRecordsForBook(options.bookId);
      await recordProvider.refreshRecentCache(bookId: options.bookId);
    }

    // 4) Tags
    final createdTags = await _ensureQaTags(
      tagProvider,
      bookId: options.bookId,
      desiredCount: options.tagCount,
    );

    // 5) Records
    final createdRecords = await _seedRecords(
      recordProvider,
      tagProvider,
      bookId: options.bookId,
      accountProvider: accountProvider,
      accounts: accountProvider.accounts,
      categories: categoryProvider.categories,
      options: options,
    );

    // Make sure UI can see it quickly.
    await recordProvider.refreshRecentCache(bookId: options.bookId);
    return QaSeedReport(
      bookId: options.bookId,
      createdAccounts: createdAccounts,
      createdTags: createdTags,
      createdRecords: createdRecords,
    );
  }

  static Future<int> _ensureQaAccounts(
    AccountProvider accountProvider, {
    required String bookId,
  }) async {
    final existingIds = accountProvider.accounts.map((a) => a.id).toSet();

    final templates = <Account>[
      const Account(
        id: 'qa_saving_card',
        name: 'QA-储蓄卡',
        kind: AccountKind.asset,
        subtype: 'saving_card',
        type: AccountType.bankCard,
        icon: 'card',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
      ),
      const Account(
        id: 'qa_credit_card',
        name: 'QA-信用卡',
        kind: AccountKind.liability,
        subtype: 'credit_card',
        type: AccountType.bankCard,
        icon: 'credit_card',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
      ),
      const Account(
        id: 'qa_virtual',
        name: 'QA-虚拟账户',
        kind: AccountKind.asset,
        subtype: 'virtual',
        type: AccountType.eWallet,
        icon: 'wallet',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
      ),
      const Account(
        id: 'qa_invest',
        name: 'QA-投资账户',
        kind: AccountKind.asset,
        subtype: 'invest',
        type: AccountType.investment,
        icon: 'trending_up',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
      ),
      const Account(
        id: 'qa_loan',
        name: 'QA-贷款',
        kind: AccountKind.liability,
        subtype: 'loan',
        type: AccountType.loan,
        icon: 'account_balance',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
      ),
      const Account(
        id: 'qa_custom_asset',
        name: 'QA-自定义资产',
        kind: AccountKind.asset,
        subtype: 'custom_asset',
        type: AccountType.other,
        icon: 'widgets',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
      ),
    ];

    var created = 0;
    for (final a in templates) {
      if (existingIds.contains(a.id)) continue;
      await accountProvider.addAccount(a, bookId: bookId, triggerSync: false);
      created++;
    }
    return created;
  }

  static Future<int> _ensureQaTags(
    TagProvider tagProvider, {
    required String bookId,
    required int desiredCount,
  }) async {
    final existing = tagProvider.tags.where((t) => t.bookId == bookId).toList();
    final need = max(0, desiredCount - existing.length);
    if (need == 0) return 0;

    final base = [
      '日常',
      '工作',
      '家庭',
      '交通',
      '餐饮',
      '娱乐',
      '医疗',
      '学习',
      '旅行',
      '纪念日',
      '报销',
      '长期',
    ];

    var created = 0;
    for (var i = 0; i < need; i++) {
      final name = i < base.length ? base[i] : 'QA-标签${i + 1}';
      await tagProvider.createTag(bookId: bookId, name: name);
      created++;
    }
    return created;
  }

  static Future<int> _seedRecords(
    RecordProvider recordProvider,
    TagProvider tagProvider, {
    required String bookId,
    required AccountProvider accountProvider,
    required List<Account> accounts,
    required List<app_model.Category> categories,
    required QaSeedOptions options,
  }) async {
    final rng = Random(options.randomSeed);
    final candidateExpenseCategories =
        categories.where((c) => c.isExpense).toList(growable: false);
    final candidateIncomeCategories =
        categories.where((c) => !c.isExpense).toList(growable: false);

    // Defensive: should never be empty, but keep seeding resilient.
    if (candidateExpenseCategories.isEmpty || candidateIncomeCategories.isEmpty) {
      throw StateError('Categories not loaded or missing income/expense sets');
    }

    final accountIds = accounts.map((a) => a.id).where((e) => e.isNotEmpty).toList();
    if (accountIds.isEmpty) {
      throw StateError('No accounts available for seeding');
    }

    // Prefer a real default wallet if present.
    final defaultWalletId = accounts
        .firstWhere(
          (a) => a.id == 'default_wallet',
          orElse: () => accounts.first,
        )
        .id;

    final tagIds = tagProvider.tags
        .where((t) => t.bookId == bookId)
        .map((t) => t.id)
        .toList(growable: false);

    // Some fixed edge-case dates first (to make “边界”稳定可测).
    final now = DateTime.now();
    final edgeDates = <DateTime>[
      DateTime(now.year, now.month, 1, 0, 0, 0),
      DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
      DateTime(now.year, 12, 31, 23, 59, 59, 999),
      DateTime(now.year, 1, 1, 0, 0, 0),
      DateTime(2024, 2, 29, 12, 0, 0), // leap day
    ];

    int created = 0;
    final total = max(0, options.recordCount);
    for (var i = 0; i < total; i++) {
      final isIncome = i % 7 == 0; // roughly 14% income

      final date = i < edgeDates.length
          ? edgeDates[i]
          : now.subtract(
              Duration(
                days: rng.nextInt(max(1, options.daysBack)),
                minutes: rng.nextInt(60 * 24),
              ),
            );

      final amount = _pickAmount(rng, index: i);
      final categoryKey = (isIncome
              ? candidateIncomeCategories[rng.nextInt(candidateIncomeCategories.length)]
              : candidateExpenseCategories[rng.nextInt(candidateExpenseCategories.length)])
          .key;

      final accountId = (i % 5 == 0)
          ? defaultWalletId
          : accountIds[rng.nextInt(accountIds.length)];

      final includeInStats = i % 23 != 0;
      final remark = includeInStats ? 'QA-$i' : 'QA-$i(不计入统计)';

      final record = await recordProvider.addRecord(
        amount: amount,
        remark: remark,
        date: date,
        categoryKey: categoryKey,
        bookId: bookId,
        accountId: accountId,
        direction: isIncome ? TransactionDirection.income : TransactionDirection.out,
        includeInStats: includeInStats,
        accountProvider: accountProvider,
      );

      // Attach 0~2 tags.
      if (tagIds.isNotEmpty) {
        final tagPick = <String>{};
        if (rng.nextBool()) tagPick.add(tagIds[rng.nextInt(tagIds.length)]);
        if (rng.nextInt(4) == 0) tagPick.add(tagIds[rng.nextInt(tagIds.length)]);
        if (tagPick.isNotEmpty) {
          await tagProvider.setTagsForRecord(
            record.id,
            tagPick.toList(),
            record: record,
          );
        }
      }

      created++;
    }
    return created;
  }

  static double _pickAmount(Random rng, {required int index}) {
    // Mix of small, normal, and occasional big numbers; stay within validator range.
    if (index == 0) return 0.01;
    if (index == 1) return 999999999.99;
    if (index % 37 == 0) {
      return (rng.nextInt(5000000) + 1000000) / 100.0; // 10,000.00 ~ 60,000.00
    }
    if (index % 5 == 0) {
      return (rng.nextInt(2000) + 1) / 100.0; // 0.01 ~ 20.00
    }
    return (rng.nextInt(200000) + 1) / 100.0; // 0.01 ~ 2000.00
  }

  static Future<void> _wipeRecordsForBook(String bookId) async {
    if (!RepositoryFactory.isUsingDatabase) {
      throw StateError('wipeExistingRecordsInBook requires DB mode');
    }
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      final ids = await txn.query(
        Tables.records,
        columns: const ['id'],
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
      final recordIds = ids.map((e) => e['id'] as String).toList(growable: false);
      if (recordIds.isNotEmpty) {
        const maxVars = 900;
        for (var i = 0; i < recordIds.length; i += maxVars) {
          final chunk = recordIds.sublist(i, min(recordIds.length, i + maxVars));
          final placeholders = List.filled(chunk.length, '?').join(',');
          await txn.delete(
            Tables.recordTags,
            where: 'record_id IN ($placeholders)',
            whereArgs: chunk,
          );
        }
      }
      await txn.delete(
        Tables.records,
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
    });
  }
}
