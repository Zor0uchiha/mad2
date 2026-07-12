import "package:hive/hive.dart";

class BookmarkModelAdapter extends TypeAdapter<BookmarkModel> {
  @override final int typeId = 6;

  @override
  BookmarkModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return BookmarkModel(
      id: fields[0] as String,
      bookId: fields[1] as String,
      title: fields[2] as String? ?? "",
      pageIndex: (fields[3] as int?) ?? 0,
      note: fields[4] as String?,
      createdAt: fields[5] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.pageIndex)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}
