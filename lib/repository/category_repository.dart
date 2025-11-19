import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';

class CategoryRepository {
  static const _key = 'categories_v1';

  static final List<Category> defaultCategories = [
    Category(
      key: 'food',
      name: '餐饮',
      icon: Icons.restaurant_outlined,
      isExpense: true,
    ),
    Category(
      key: 'shopping',
      name: '购物',
      icon: Icons.local_mall_outlined,
      isExpense: true,
    ),
    Category(
      key: 'transport',
      name: '交通出行',
      icon: Icons.directions_bus_outlined,
      isExpense: true,
    ),
    Category(
      key: 'utility',
      name: '水电煤',
      icon: Icons.electric_bolt,
      isExpense: true,
    ),
    Category(
      key: 'medical',
      name: '医疗',
      icon: Icons.medical_services_outlined,
      isExpense: true,
    ),
    Category(
      key: 'education',
      name: '教育',
      icon: Icons.school_outlined,
      isExpense: true,
    ),
    Category(
      key: 'house',
      name: '住房',
      icon: Icons.house_outlined,
      isExpense: true,
    ),
    Category(
      key: 'entertainment',
      name: '娱乐',
      icon: Icons.sports_esports_outlined,
      isExpense: true,
    ),
    Category(
      key: 'daily',
      name: '日用品',
      icon: Icons.inventory_2_outlined,
      isExpense: true,
    ),
    Category(
      key: 'pet',
      name: '宠物',
      icon: Icons.pets_outlined,
      isExpense: true,
    ),
    Category(
      key: 'salary',
      name: '工资',
      icon: Icons.attach_money,
      isExpense: false,
    ),
    Category(
      key: 'bonus',
      name: '奖金',
      icon: Icons.card_giftcard,
      isExpense: false,
    ),
    Category(
      key: 'parttime',
      name: '兼职',
      icon: Icons.work_outline,
      isExpense: false,
    ),
    Category(
      key: 'invest',
      name: '投资收益',
      icon: Icons.trending_up,
      isExpense: false,
    ),
  ];

  Future<List<Category>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null) {
      await saveCategories(defaultCategories);
      return List<Category>.from(defaultCategories);
    }

    return raw.map((value) => Category.fromJson(value)).toList();
  }

  Future<void> saveCategories(List<Category> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = categories.map((c) => c.toJson()).toList();
    await prefs.setStringList(_key, payload);
  }

  Future<List<Category>> add(Category category) async {
    final list = await loadCategories();
    list.add(category);
    await saveCategories(list);
    return list;
  }

  Future<List<Category>> delete(String key) async {
    final list = await loadCategories();
    list.removeWhere((element) => element.key == key);
    await saveCategories(list);
    return list;
  }

  Future<List<Category>> update(Category category) async {
    final list = await loadCategories();
    final index = list.indexWhere((c) => c.key == category.key);
    if (index != -1) {
      list[index] = category;
      await saveCategories(list);
    }
    return list;
  }
}
