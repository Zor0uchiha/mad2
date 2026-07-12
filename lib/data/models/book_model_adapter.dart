import "package:hive/hive.dart";

class BookFormatAdapter extends TypeAdapter<BookFormat> {
  @override final int typeId = 0;

  @override
  BookFormat read(BinaryReader reader) {
    return BookFormat.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, BookFormat obj) {
    writer.writeByte(obj.index);
  }
}

class BookModelAdapter extends TypeAdapter<BookModel> {
  @override final int typeId = 1;

  @override
  BookModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return BookModel(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      description: fields[3] as String?,
      coverPath: fields[4] as String?,
      filePath: fields[5] as String?,
      format: BookFormat.values[(fields[6] as int?) ?? 0],
      pageCount: (fields[7] as int?) ?? 0,
      currentPage: (fields[8] as int?) ?? 0,
      progress: (fields[9] as double?) ?? 0.0,
      tags: (fields[10] as List?)?.cast<String>() ?? const [],
      isFavorite: (fields[11] as bool?) ?? false,
      lastOpenedAt: fields[12] as DateTime?,
      createdAt: fields[13] as DateTime? ?? DateTime.now(),
      updatedAt: fields[14] as DateTime? ?? DateTime.now(),
      isbn: fields[15] as String?,
      publisher: fields[16] as String?,
      language: fields[17] as String?,
      publishedDate: fields[18] as DateTime?,
      collectionIds: (fields[19] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, BookModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.coverPath)
      ..writeByte(5)
      ..write(obj.filePath)
      ..writeByte(6)
      ..write(obj.format.index)
      ..writeByte(7)
      ..write(obj.pageCount)
      ..writeByte(8)
      ..write(obj.currentPage)
      ..writeByte(9)
      ..write(obj.progress)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.isFavorite)
      ..writeByte(12)
      ..write(obj.lastOpenedAt)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.isbn)
      ..writeByte(16)
      ..write(obj.publisher)
      ..writeByte(17)
      ..write(obj.language)
      ..writeByte(18)
      ..write(obj.publishedDate)
      ..writeByte(19)
      ..write(obj.collectionIds);
  }
}
