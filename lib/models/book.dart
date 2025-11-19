import 'dart:convert';

class Book {
  final String id;
  final String name;

  const Book({
    required this.id,
    required this.name,
  });

  Book copyWith({String? id, String? name}) {
    return Book(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Book.fromJson(String source) =>
      Book.fromMap(json.decode(source) as Map<String, dynamic>);
}
