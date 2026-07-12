import "package:flutter/material.dart";
import "package:hive/hive.dart";

@HiveType(typeId: 2)
class CollectionModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? iconName;

  @HiveField(4)
  int colorValue;

  @HiveField(5)
  List<String> bookIds;

  @HiveField(6)
  int sortOrder;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  CollectionModel({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.colorValue = 0xFF1A73E8,
    this.bookIds = const [],
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);

  int get bookCount => bookIds.length;

  CollectionModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    int? colorValue,
    List<String>? bookIds,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      bookIds: bookIds ?? this.bookIds,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
