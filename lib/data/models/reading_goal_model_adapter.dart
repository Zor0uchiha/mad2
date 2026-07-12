import "package:hive/hive.dart";

class ReadingGoalModelAdapter extends TypeAdapter<ReadingGoalModel> {
  @override final int typeId = 9;

  @override
  ReadingGoalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ReadingGoalModel(
      booksPerYear: (fields[0] as int?) ?? 12,
      pagesPerYear: (fields[1] as int?) ?? 3650,
      minutesPerDay: (fields[2] as int?) ?? 20,
      updatedAt: fields[3] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingGoalModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.booksPerYear)
      ..writeByte(1)
      ..write(obj.pagesPerYear)
      ..writeByte(2)
      ..write(obj.minutesPerDay)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }
}
