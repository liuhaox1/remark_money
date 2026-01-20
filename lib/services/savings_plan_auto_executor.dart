import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/record.dart';
import '../models/savings_plan.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../repository/record_repository.dart';
import '../repository/record_repository_db.dart';
import '../repository/repository_factory.dart';
import '../repository/savings_plan_repository.dart';
import '../utils/savings_plan_schedule.dart';

class SavingsPlanAutoRunResult {
  const SavingsPlanAutoRunResult({
    required this.executedPeriods,
    required this.skippedPeriods,
  });

  final int executedPeriods;
  final int skippedPeriods;
}

class SavingsPlanAutoExecutor {
  SavingsPlanAutoExecutor._();

  static final SavingsPlanAutoExecutor instance = SavingsPlanAutoExecutor._();

  Future<SavingsPlanAutoRunResult> runForActiveBook(
    BuildContext context, {
    String? onlyPlanId,
    DateTime? now,
  }) async {
    final bookId = context.read<BookProvider>().activeBookId;
    return runForBook(
      context,
      bookId,
      onlyPlanId: onlyPlanId,
      now: now,
    );
  }

  Future<SavingsPlanAutoRunResult> runForBook(
    BuildContext context,
    String bookId, {
    String? onlyPlanId,
    DateTime? now,
  }) async {
    final plans = await SavingsPlanRepository().loadPlans(bookId: bookId);
    final candidates = plans.where((p) {
      if (onlyPlanId != null && p.id != onlyPlanId) return false;
      return p.type == SavingsPlanType.monthlyFixed || p.type == SavingsPlanType.weeklyFixed;
    }).toList(growable: false);

    if (candidates.isEmpty) {
      return const SavingsPlanAutoRunResult(executedPeriods: 0, skippedPeriods: 0);
    }

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    final nowTime = now ?? DateTime.now();

    int executed = 0;
    int skipped = 0;

    for (final plan in candidates) {
      final planAccount = _findAccount(accounts, plan.accountId);
      if (planAccount == null) {
        skipped += 1;
        continue;
      }

      final periods = computeDuePeriods(plan, now: nowTime);
      if (periods.isEmpty) continue;

      var fromAccountId = plan.defaultFromAccountId;
      fromAccountId = _resolveFromAccountId(
        fromAccountId,
        accounts: accounts,
        planAccountId: plan.accountId,
      );
      if (fromAccountId == null) {
        skipped += periods.length;
        continue;
      }

      final (executedForPlan, skippedForPlan, addedAmount, lastExecutedAt) =
          await _executePlanPeriods(
        context,
        plan,
        bookId: bookId,
        fromAccountId: fromAccountId,
        periods: periods,
        recordProvider: recordProvider,
        accountProvider: accountProvider,
      );

      executed += executedForPlan;
      skipped += skippedForPlan;

      if (executedForPlan > 0) {
        final updated = plan.copyWith(
          savedAmount: plan.savedAmount + addedAmount,
          executedCount: plan.executedCount + executedForPlan,
          lastExecutedAt: lastExecutedAt,
          defaultFromAccountId: fromAccountId,
          updatedAt: DateTime.now(),
        );
        try {
          await SavingsPlanRepository().upsertPlan(updated);
        } catch (e) {
          debugPrint('[SavingsPlanAutoExecutor] update plan failed: $e');
        }
      } else if (plan.defaultFromAccountId != fromAccountId) {
        // Best-effort: persist chosen fallback debit account for future auto runs.
        try {
          await SavingsPlanRepository().upsertPlan(
            plan.copyWith(defaultFromAccountId: fromAccountId, updatedAt: DateTime.now()),
          );
        } catch (_) {}
      }
    }

    return SavingsPlanAutoRunResult(executedPeriods: executed, skippedPeriods: skipped);
  }

  Account? _findAccount(List<Account> accounts, String id) {
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  String? _resolveFromAccountId(
    String? preferred, {
    required List<Account> accounts,
    required String planAccountId,
  }) {
    if (preferred != null && preferred.isNotEmpty && preferred != planAccountId) {
      final exists = accounts.any((a) => a.id == preferred);
      if (exists) return preferred;
    }
    // Fallback to the first asset account shown in overview.
    for (final a in accounts) {
      if (a.id == planAccountId) continue;
      if (a.kind == AccountKind.asset && a.includeInOverview) return a.id;
    }
    // Last resort: any account other than plan account.
    for (final a in accounts) {
      if (a.id != planAccountId) return a.id;
    }
    return null;
  }

  Future<(int executed, int skipped, double addedAmount, DateTime? lastExecutedAt)>
      _executePlanPeriods(
    BuildContext context,
    SavingsPlan plan, {
    required String bookId,
    required String fromAccountId,
    required List<SavingsPlanDuePeriod> periods,
    required RecordProvider recordProvider,
    required AccountProvider accountProvider,
  }) async {
    var executed = 0;
    var skipped = 0;
    var addedAmount = 0.0;
    DateTime? lastExecutedAt;

    for (final p in periods) {
      final pairId = 'sp_${plan.id}_${p.key}';
      final (count, existing) = await _loadPair(bookId: bookId, pairId: pairId);
      if (count >= 2) {
        continue;
      }
      if (count == 1) {
        // Heal partial transfer: create the missing leg.
        try {
          final e = existing.first;
          final dueAt = DateTime(p.dueDate.year, p.dueDate.month, p.dueDate.day, 12);
          if (e.direction == TransactionDirection.out) {
            await recordProvider.addRecord(
              amount: e.amount,
              remark: e.remark,
              date: dueAt,
              categoryKey: 'saving-in',
              bookId: bookId,
              accountId: plan.accountId,
              direction: TransactionDirection.income,
              includeInStats: false,
              pairId: pairId,
              accountProvider: accountProvider,
            );
          } else {
            await recordProvider.addRecord(
              amount: e.amount,
              remark: e.remark,
              date: dueAt,
              categoryKey: 'saving-out',
              bookId: bookId,
              accountId: fromAccountId,
              direction: TransactionDirection.out,
              includeInStats: false,
              pairId: pairId,
              accountProvider: accountProvider,
            );
          }
        } catch (e) {
          debugPrint('[SavingsPlanAutoExecutor] heal partial failed: $e');
          skipped++;
        }
        continue;
      }

      if (p.amount <= 0) {
        skipped++;
        continue;
      }
      if (fromAccountId == plan.accountId) {
        skipped++;
        continue;
      }

      // Use a stable time so sorting is deterministic.
      final dueAt = DateTime(p.dueDate.year, p.dueDate.month, p.dueDate.day, 12);
      final remark = plan.name.trim().isEmpty ? '存钱' : plan.name.trim();
      try {
        await recordProvider.addRecord(
          amount: p.amount,
          remark: remark,
          date: dueAt,
          categoryKey: 'saving-out',
          bookId: bookId,
          accountId: fromAccountId,
          direction: TransactionDirection.out,
          includeInStats: false,
          pairId: pairId,
          accountProvider: accountProvider,
        );
        await recordProvider.addRecord(
          amount: p.amount,
          remark: remark,
          date: dueAt,
          categoryKey: 'saving-in',
          bookId: bookId,
          accountId: plan.accountId,
          direction: TransactionDirection.income,
          includeInStats: false,
          pairId: pairId,
          accountProvider: accountProvider,
        );
        executed++;
        addedAmount += p.amount;
        lastExecutedAt = dueAt;
      } catch (e) {
        debugPrint('[SavingsPlanAutoExecutor] execute failed: $e');
        skipped++;
      }
    }

    return (executed, skipped, addedAmount, lastExecutedAt);
  }

  Future<(int count, List<Record> records)> _loadPair({
    required String bookId,
    required String pairId,
  }) async {
    if (RepositoryFactory.isUsingDatabase) {
      final repo = RecordRepositoryDb();
      final list = await repo.loadByPairId(bookId: bookId, pairId: pairId);
      return (list.length, list);
    }
    final repo = RecordRepository();
    final list = await repo.loadByPairId(bookId: bookId, pairId: pairId);
    return (list.length, list);
  }
}

