import 'package:flutter/material.dart';
import '../models/category.dart';
import '../repository/category_repository.dart';
import '../repository/repository_factory.dart';

class CategoryProvider extends ChangeNotifier {
  // SharedPreferences 版和数据库版方法签名一致，这里用 dynamic 接收
  final dynamic _repo = RepositoryFactory.createCategoryRepository();
  final List<Category> _categories = [];

  List<Category> get categories => List.unmodifiable(_categories);

  bool _loaded = false;
  bool get loaded => _loaded;

  Category _sanitize(Category c) =>
      c.copyWith(name: CategoryRepository.sanitizeCategoryName(c.key, c.name));

  /// 加载所有分类
  Future<void> load() async {
    if (_loaded) return;

    final List<Category> list =
        (await _repo.loadCategories()).cast<Category>();
    _categories
      ..clear()
      ..addAll(list.map(_sanitize));
    _loaded = true;
    notifyListeners();
  }

  /// 新增分类
  Future<void> addCategory(Category c) async {
    final List<Category> list = (await _repo.add(c)).cast<Category>();
    _categories
      ..clear()
      ..addAll(list.map(_sanitize));
    notifyListeners();
  }

  /// 删除分类
  Future<void> deleteCategory(String key) async {
    final List<Category> list = (await _repo.delete(key)).cast<Category>();
    _categories
      ..clear()
      ..addAll(list.map(_sanitize));
    notifyListeners();
  }

  /// 更新分类（名称 / 图标 / 类型）
  Future<void> updateCategory(Category category) async {
    final List<Category> list =
        (await _repo.update(category)).cast<Category>();
    _categories
      ..clear()
      ..addAll(list.map(_sanitize));
    notifyListeners();
  }
}
