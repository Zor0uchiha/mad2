import "package:hive/hive.dart";
import "review_model.dart";

class ReviewModelAdapter extends TypeAdapter<ReviewModel> {
  @override final int typeId = 4;

  @override
  ReviewModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ReviewModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      userName: fields[2] as String,
      bookId: fields[3] as String,
      rating: (fields[4] as double?) ?? 0,
      text: fields[5] as String? ?? "",
      hasSpoiler: (fields[6] as bool?) ?? false,
      tags: (fields[7] as List?)?.cast<String>() ?? const [],
      readingDate: fields[8] as DateTime?,
      isPublic: (fields[9] as bool?) ?? true,
      createdAt: fields[10] as DateTime? ?? DateTime.now(),
      updatedAt: fields[11] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, ReviewModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.bookId)
      ..writeByte(4)
      ..write(obj.rating)
      ..writeByte(5)
      ..write(obj.text)
      ..writeByte(6)
      ..write(obj.hasSpoiler)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.readingDate)
      ..writeByte(9)
      ..write(obj.isPublic)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }
}
