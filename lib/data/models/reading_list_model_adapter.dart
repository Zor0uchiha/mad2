import "package:hive/hive.dart";

class ReadingListModelAdapter extends TypeAdapter<ReadingListModel> {
  @override final int typeId = 5;

  @override
  ReadingListModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ReadingListModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      coverUrl: fields[3] as String?,
      userId: fields[4] as String,
      bookIds: (fields[5] as List?)?.cast<String>() ?? const [],
      isPublic: (fields[6] as bool?) ?? false,
      sortOrder: (fields[7] as int?) ?? 0,
      createdAt: fields[8] as DateTime? ?? DateTime.now(),
      updatedAt: fields[9] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingListModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.coverUrl)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.bookIds)
      ..writeByte(6)
      ..write(obj.isPublic)
      ..writeByte(7)
      ..write(obj.sortOrder)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }
}
