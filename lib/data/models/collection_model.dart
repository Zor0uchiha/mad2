import 'package:flutter/material.dart';

class CollectionModel {
  String id;
  String name;
  String? description;
  String? iconName;
  int colorValue;
  List<String> bookIds;
  int sortOrder;
  DateTime createdAt;
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
