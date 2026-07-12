import "package:hive/hive.dart";
import "note_model.dart";

class NoteModelAdapter extends TypeAdapter<NoteModel> {
  @override final int typeId = 7;

  @override
  NoteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return NoteModel(
      id: fields[0] as String,
      bookId: fields[1] as String,
      pageIndex: (fields[2] as int?) ?? 0,
      text: fields[3] as String? ?? "",
      createdAt: fields[4] as DateTime? ?? DateTime.now(),
      updatedAt: fields[5] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, NoteModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.pageIndex)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }
}
