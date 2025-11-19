import 'package:flutter/material.dart';
import '../models/category.dart';
import '../repository/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repo = CategoryRepository();
  final List<Category> _categories = [];

  List<Category> get categories => List.unmodifiable(_categories);

  bool _loaded = false;
  bool get loaded => _loaded;

  /// 加载所有分类
  Future<void> load() async {
    if (_loaded) return;

    final list = await _repo.loadCategories();
    _categories
      ..clear()
      ..addAll(list);
    _loaded = true;
    notifyListeners();
  }

  /// 新增分类
  Future<void> addCategory(Category c) async {
    final list = await _repo.add(c);
    _categories
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// 删除分类
  Future<void> deleteCategory(String key) async {
    final list = await _repo.delete(key);
    _categories
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// 更新分类（名称 / 图标 / 类型）
  Future<void> updateCategory(Category category) async {
    final list = await _repo.update(category);
    _categories
      ..clear()
      ..addAll(list);
    notifyListeners();
  }
}
