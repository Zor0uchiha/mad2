import "package:hive/hive.dart";

@HiveType(typeId: 7)
class NoteModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String bookId;

  @HiveField(2)
  int pageIndex;

  @HiveField(3)
  String text;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.bookId,
    required this.pageIndex,
    this.text = "",
    required this.createdAt,
    required this.updatedAt,
  });

  NoteModel copyWith({
    String? id,
    String? bookId,
    int? pageIndex,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageIndex: pageIndex ?? this.pageIndex,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
