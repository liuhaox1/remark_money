import 'dart:convert';
import 'package:flutter/material.dart';

class Category {
  final String key;
  final String name;
  final IconData icon;
  final bool isExpense;
  /// 一级分类 key；为 null 表示自己就是一级分类
  final String? parentKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    required this.key,
    required this.name,
    required this.icon,
    required this.isExpense,
    this.parentKey,
    this.createdAt,
    this.updatedAt,
  });

  Category copyWith({
    String? key,
    String? name,
    IconData? icon,
    bool? isExpense,
    String? parentKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      key: key ?? this.key,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isExpense: isExpense ?? this.isExpense,
      parentKey: parentKey ?? this.parentKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }
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
      createdAt: parse(map['createdAt']),
      updatedAt: parse(map['updatedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Category.fromJson(String source) =>
      Category.fromMap(json.decode(source));
}
