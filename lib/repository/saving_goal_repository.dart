import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saving_goal.dart';
import '../models/saving_goal_contribution.dart';

class SavingGoalRepository {
  static const _goalKey = 'saving_goals_v1';
  static const _contributionKey = 'saving_goal_contributions_v1';

  Future<List<SavingGoal>> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_goalKey) ?? [];
    return raw.map((s) => SavingGoal.fromJson(s)).toList();
  }

  Future<void> saveGoals(List<SavingGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _goalKey,
      goals.map((g) => g.toJson()).toList(),
    );
  }

  Future<List<SavingGoalContribution>> loadContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_contributionKey) ?? [];
    return raw.map((s) => SavingGoalContribution.fromJson(s)).toList();
  }

  Future<void> saveContributions(
    List<SavingGoalContribution> contributions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _contributionKey,
      contributions.map((c) => c.toJson()).toList(),
    );
  }
}
