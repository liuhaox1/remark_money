import 'dart:convert';

class Tag {
  const Tag({
    required this.id,
    required this.bookId,
    required this.name,
    this.colorValue,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bookId;
  final String name;
  final int? colorValue;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tag copyWith({
    String? id,
    String? bookId,
    String? name,
    int? colorValue,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
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
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
      name: map['name'] as String? ?? '',
      colorValue: map['colorValue'] as int?,
      sortOrder: (map['sortOrder'] as int?) ?? 0,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
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

