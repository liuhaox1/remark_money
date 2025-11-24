import 'dart:math';

import 'package:flutter/material.dart';

import '../models/saving_goal.dart';
import '../models/saving_goal_contribution.dart';
import '../repository/saving_goal_repository.dart';
import '../utils/date_utils.dart';

class SavingGoalProvider extends ChangeNotifier {
  SavingGoalProvider();

  final SavingGoalRepository _repository = SavingGoalRepository();
  final List<SavingGoal> _goals = [];
  final List<SavingGoalContribution> _contributions = [];
  final Random _random = Random();
  bool _loaded = false;

  List<SavingGoal> get goals => List.unmodifiable(_goals);
  List<SavingGoalContribution> get contributions =>
      List.unmodifiable(_contributions);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final goalList = await _repository.loadGoals();
    final contributionList = await _repository.loadContributions();
    _goals
      ..clear()
      ..addAll(goalList);
    _contributions
      ..clear()
      ..addAll(contributionList);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _repository.saveGoals(_goals);
    await _repository.saveContributions(_contributions);
    notifyListeners();
  }

  Future<void> addGoal(SavingGoal goal) async {
    _goals.add(goal.copyWith(id: _generateId()));
    await _persist();
  }

  Future<void> updateGoal(SavingGoal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index == -1) return;
    _goals[index] = goal.copyWith(updatedAt: DateTime.now());
    await _persist();
  }

  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    _contributions.removeWhere((c) => c.goalId == goalId);
    await _persist();
  }

  Future<void> addContribution({
    required String goalId,
    required String recordId,
    required double amount,
    required DateTime date,
  }) async {
    if (amount <= 0) return;
    final exists = _contributions.any((c) => c.transactionId == recordId);
    if (exists) return;
    _contributions.add(
      SavingGoalContribution(
        id: _generateId(),
        goalId: goalId,
        transactionId: recordId,
        amount: amount,
        date: date,
      ),
    );
    await _persist();
  }

  Future<void> removeContributionByRecord(String recordId) async {
    _contributions.removeWhere((c) => c.transactionId == recordId);
    await _persist();
  }

  SavingGoal? goalForAccount(String accountId) {
    try {
      return _goals.firstWhere((g) => g.accountId == accountId);
    } catch (_) {
      return null;
    }
  }

  double contributedAmount(String goalId) {
    return _contributions
        .where((c) => c.goalId == goalId)
        .fold(0, (sum, c) => sum + c.amount);
  }

  double todayContribution(String goalId, DateTime day) {
    return _contributions.where((c) {
      return c.goalId == goalId && DateUtilsX.isSameDay(c.date, day);
    }).fold(0, (sum, c) => sum + c.amount);
  }

  SavingGoalStatus resolveStatus(SavingGoal goal) {
    final contributed = contributedAmount(goal.id);
    if (contributed >= goal.targetAmount) {
      return SavingGoalStatus.completed;
    }
    if (goal.endDate != null && DateTime.now().isAfter(goal.endDate!)) {
      return SavingGoalStatus.overdue;
    }
    return goal.status;
  }

  double amountProgress(SavingGoal goal) {
    final contributed = contributedAmount(goal.id);
    if (goal.targetAmount == 0) return 0;
    return (contributed / goal.targetAmount).clamp(0, 1);
  }

  double timeProgress(SavingGoal goal) {
    if (goal.endDate == null) return 0;
    final total = goal.endDate!.difference(goal.startDate).inDays + 1;
    if (total <= 0) return 0;
    final now = DateTime.now();
    final passed = now.isBefore(goal.startDate)
        ? 0
        : now.difference(goal.startDate).inDays + 1;
    return (passed / total).clamp(0, 1);
  }

  double suggestedDailyAmount(SavingGoal goal) {
    if (goal.endDate == null) return 0;
    final totalDays = goal.endDate!.difference(goal.startDate).inDays + 1;
    if (totalDays <= 0) return 0;
    return goal.targetAmount / totalDays;
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
