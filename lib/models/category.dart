import 'dart:convert';
import 'package:flutter/material.dart';

class Category {
  final String key;
  final String name;
  final IconData icon;
  final bool isExpense;
  /// 一级分类 key；为 null 表示自己就是一级分类
  final String? parentKey;

  Category({
    required this.key,
    required this.name,
    required this.icon,
    required this.isExpense,
    this.parentKey,
  });

  Category copyWith({
    String? key,
    String? name,
    IconData? icon,
    bool? isExpense,
    String? parentKey,
  }) {
    return Category(
      key: key ?? this.key,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isExpense: isExpense ?? this.isExpense,
      parentKey: parentKey ?? this.parentKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'name': name,
      'icon': icon.codePoint,
      'fontFamily': icon.fontFamily,
      'fontPackage': icon.fontPackage,
      'isExpense': isExpense,
      'parentKey': parentKey,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      key: map['key'],
      name: map['name'],
      icon: IconData(
        map['icon'],
        fontFamily: map['fontFamily'],
        fontPackage: map['fontPackage'],
      ),
      isExpense: map['isExpense'],
      parentKey: map['parentKey'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Category.fromJson(String source) =>
      Category.fromMap(json.decode(source));
}
