import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../repository/repository_factory.dart';
import '../services/meta_sync_notifier.dart';
import '../utils/error_handler.dart';
import '../services/budget_sync_state_store.dart';
import '../services/data_version_service.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider();

  // SharedPreferences / 数据库 两种实现共用相同方法签名
  final dynamic _repository = RepositoryFactory.createBudgetRepository();

  Budget _budgetStore = Budget.empty();
  Budget get store => _budgetStore;

  bool _loaded = false;
  bool get loaded => _loaded;

  int _changeCounter = 0;
  int get changeCounter => _changeCounter;

  void _notifyChanged() {
    _changeCounter++;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      _budgetStore = await _repository.loadBudget();
      _loaded = true;
      _notifyChanged();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BudgetProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  BudgetEntry budgetForBook(String bookId) {
    return _budgetStore.entryFor(bookId);
  }

  Future<void> updateBudgetForBook({
    required String bookId,
    required double totalBudget,
    required Map<String, double> categoryBudgets,
    double? annualBudget,
    Map<String, double>? annualCategoryBudgets,
    int? periodStartDay,
    bool markUserEdited = true,
  }) async {
    try {
      final current = _budgetStore.entries[bookId];
      final entry = BudgetEntry(
        total: totalBudget,
        categoryBudgets: Map<String, double>.from(categoryBudgets),
        periodStartDay: periodStartDay ?? current?.periodStartDay ?? 1,
        annualTotal: annualBudget ?? current?.annualTotal ?? 0,
        annualCategoryBudgets: Map<String, double>.from(
          annualCategoryBudgets ?? current?.annualCategoryBudgets ?? const {},
        ),
      );
      _budgetStore = _budgetStore.replaceEntry(bookId, entry);
      await _repository.saveBudget(_budgetStore);
      // 数据修改时版本号+1
      await DataVersionService.incrementVersion(bookId);
      if (markUserEdited) {
        final baseVersion =
            await BudgetSyncStateStore.getServerSyncVersion(bookId);
        await BudgetSyncStateStore.setLocalBaseSyncVersion(
          bookId,
          baseVersion,
        );
        await BudgetSyncStateStore.setLocalEditMs(
          bookId,
          DateTime.now().millisecondsSinceEpoch,
        );
        MetaSyncNotifier.instance.notifyBudgetChanged(bookId);
      }
      _notifyChanged();
    } catch (e, stackTrace) {
      ErrorHandler.logError('BudgetProvider.updateBudgetForBook', e, stackTrace);
      rethrow;
    }
  }

  Future<void> setTotal(String bookId, double value) async {
    final current = budgetForBook(bookId);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: value,
      categoryBudgets: current.categoryBudgets,
      annualBudget: current.annualTotal,
    );
  }

  Future<void> setAnnualTotal(String bookId, double value) async {
    final current = budgetForBook(bookId);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: current.categoryBudgets,
      annualBudget: value,
    );
  }

  Future<void> setCategoryBudget(
    String bookId,
    String key,
    double value,
  ) async {
    final current = budgetForBook(bookId);
    final updated = {...current.categoryBudgets, key: value};
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: updated,
      annualBudget: current.annualTotal,
      annualCategoryBudgets: current.annualCategoryBudgets,
    );
  }

  Future<void> deleteCategoryBudget(String bookId, String key) async {
    final current = budgetForBook(bookId);
    final updated = {...current.categoryBudgets}..remove(key);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: updated,
      annualBudget: current.annualTotal,
      annualCategoryBudgets: current.annualCategoryBudgets,
    );
  }

  Future<void> setAnnualCategoryBudget(
    String bookId,
    String key,
    double value,
  ) async {
    final current = budgetForBook(bookId);
    final updated = {...current.annualCategoryBudgets, key: value};
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: current.categoryBudgets,
      annualBudget: current.annualTotal,
      annualCategoryBudgets: updated,
    );
  }

  Future<void> deleteAnnualCategoryBudget(String bookId, String key) async {
    final current = budgetForBook(bookId);
    final updated = {...current.annualCategoryBudgets}..remove(key);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: current.categoryBudgets,
      annualBudget: current.annualTotal,
      annualCategoryBudgets: updated,
    );
  }

  Future<void> setPeriodStartDay(String bookId, int day) async {
    final safeDay = day.clamp(1, 28);
    final current = budgetForBook(bookId);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: current.categoryBudgets,
      periodStartDay: safeDay,
    );
  }

  Future<void> resetBudgetForBook(String bookId) async {
    try {
      final current = budgetForBook(bookId);
      await updateBudgetForBook(
        bookId: bookId,
        totalBudget: 0,
        categoryBudgets: const {},
        annualBudget: 0,
        annualCategoryBudgets: const {},
        periodStartDay: current.periodStartDay,
        markUserEdited: true,
      );
    } catch (e, stackTrace) {
      ErrorHandler.logError('BudgetProvider.resetBudgetForBook', e, stackTrace);
      rethrow;
    }
  }

  /// 当前账本在指定日期下的预算周期（起止日）
  DateTimeRange currentPeriodRange(String bookId, DateTime anchor) {
    final entry = budgetForBook(bookId);
    final startDay = entry.periodStartDay.clamp(1, 28);
    final today = DateTime(anchor.year, anchor.month, anchor.day);

    late DateTime start;
    late DateTime end;

    if (today.day >= startDay) {
      start = DateTime(today.year, today.month, startDay);
      end = DateTime(today.year, today.month + 1, startDay)
          .subtract(const Duration(days: 1));
    } else {
      start = DateTime(today.year, today.month - 1, startDay);
      end = DateTime(today.year, today.month, startDay)
          .subtract(const Duration(days: 1));
    }

    return DateTimeRange(start: start, end: end);
  }
}
