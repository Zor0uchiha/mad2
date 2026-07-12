class BookmarkModel {
  String id;
  String bookId;
  String bookTitle;
  String title;
  int pageIndex;
  String? note;
  DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.bookId,
    this.bookTitle = '',
    this.title = '',
    required this.pageIndex,
    this.note,
    required this.createdAt,
  });

  BookmarkModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? title,
    int? pageIndex,
    String? note,
    DateTime? createdAt,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      title: title ?? this.title,
      pageIndex: pageIndex ?? this.pageIndex,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
