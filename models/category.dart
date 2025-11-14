import 'dart:convert';
import 'package:flutter/material.dart';

class Category {
  final String key;
  final String name;
  final IconData icon;
  final bool isExpense;

  Category({
    required this.key,
    required this.name,
    required this.icon,
    required this.isExpense,
  });

  Category copyWith({
    String? key,
    String? name,
    IconData? icon,
    bool? isExpense,
  }) {
    return Category(
      key: key ?? this.key,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isExpense: isExpense ?? this.isExpense,
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
    );
  }

  String toJson() => json.encode(toMap());

  factory Category.fromJson(String source) =>
      Category.fromMap(json.decode(source));
}
