import 'dart:convert';

class Tag {
  const Tag({
    required this.id,
    required this.bookId,
    required this.name,
    this.syncVersion,
    this.colorValue,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bookId;
  final String name;
  final int? syncVersion;
  final int? colorValue;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tag copyWith({
    String? id,
    String? bookId,
    String? name,
    int? syncVersion,
    int? colorValue,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      syncVersion: syncVersion ?? this.syncVersion,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'name': name,
      'syncVersion': syncVersion,
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }
    return Tag(
      id: map['id'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
      name: map['name'] as String? ?? '',
      syncVersion: map['syncVersion'] is num
          ? (map['syncVersion'] as num).toInt()
          : (map['syncVersion'] is String
              ? int.tryParse(map['syncVersion'])
              : null),
      colorValue: map['colorValue'] as int?,
      sortOrder: (map['sortOrder'] as int?) ?? 0,
      createdAt: parse(map['createdAt']),
      updatedAt: parse(map['updatedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Tag.fromJson(String source) =>
      Tag.fromMap(json.decode(source) as Map<String, dynamic>);
}

class TagPalette {
  static const List<int> defaultColors = <int>[
    0xFF4CAF50, // green
    0xFF2196F3, // blue
    0xFFFFC107, // amber
    0xFFE91E63, // pink
    0xFF9C27B0, // purple
    0xFF00BCD4, // cyan
    0xFFFF5722, // deep orange
    0xFF607D8B, // blue grey
  ];
}
