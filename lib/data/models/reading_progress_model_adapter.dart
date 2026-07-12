import "package:hive/hive.dart";
import "reading_progress_model.dart";

class ReadingProgressModelAdapter extends TypeAdapter<ReadingProgressModel> {
  @override final int typeId = 8;

  @override
  ReadingProgressModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ReadingProgressModel(
      id: fields[0] as String,
      bookId: fields[1] as String,
      currentPage: (fields[2] as int?) ?? 0,
      progressPercentage: (fields[3] as double?) ?? 0.0,
      totalPages: fields[4] as int?,
      lastReadAt: fields[5] as DateTime? ?? DateTime.now(),
      readingTimeMinutes: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingProgressModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.currentPage)
      ..writeByte(3)
      ..write(obj.progressPercentage)
      ..writeByte(4)
      ..write(obj.totalPages)
      ..writeByte(5)
      ..write(obj.lastReadAt)
      ..writeByte(6)
      ..write(obj.readingTimeMinutes);
  }
}
