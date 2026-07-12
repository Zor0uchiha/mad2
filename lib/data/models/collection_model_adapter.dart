import "package:hive/hive.dart";
import "package:flutter/material.dart";

class CollectionModelAdapter extends TypeAdapter<CollectionModel> {
  @override final int typeId = 2;

  @override
  CollectionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return CollectionModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      iconName: fields[3] as String?,
      colorValue: (fields[4] as int?) ?? 0xFF1A73E8,
      bookIds: (fields[5] as List?)?.cast<String>() ?? const [],
      sortOrder: (fields[6] as int?) ?? 0,
      createdAt: fields[7] as DateTime? ?? DateTime.now(),
      updatedAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, CollectionModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.iconName)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.bookIds)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}
