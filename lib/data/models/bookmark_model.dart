import "package:hive/hive.dart";

@HiveType(typeId: 6)
class BookmarkModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String bookId;

  @HiveField(2)
  String title;

  @HiveField(3)
  int pageIndex;

  @HiveField(4)
  String? note;

  @HiveField(5)
  DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.bookId,
    this.title = "",
    required this.pageIndex,
    this.note,
    required this.createdAt,
  });

  BookmarkModel copyWith({
    String? id,
    String? bookId,
    String? title,
    int? pageIndex,
    String? note,
    DateTime? createdAt,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      pageIndex: pageIndex ?? this.pageIndex,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
