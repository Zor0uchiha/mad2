class NoteModel {
  String id;
  String bookId;
  String bookTitle;
  int pageIndex;
  String text;
  DateTime createdAt;
  DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.bookId,
    this.bookTitle = '',
    required this.pageIndex,
    this.text = '',
    required this.createdAt,
    required this.updatedAt,
  });

  NoteModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    int? pageIndex,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      pageIndex: pageIndex ?? this.pageIndex,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
