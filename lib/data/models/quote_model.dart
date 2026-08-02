class QuoteModel {
  String id;
  String bookId;
  String bookTitle;
  String bookAuthor;
  int pageIndex;
  String text;
  double normalizedTop;
  double normalizedBottom;
  DateTime createdAt;

  QuoteModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.pageIndex,
    required this.text,
    this.normalizedTop = 0,
    this.normalizedBottom = 0,
    required this.createdAt,
  });

  QuoteModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? bookAuthor,
    int? pageIndex,
    String? text,
    double? normalizedTop,
    double? normalizedBottom,
    DateTime? createdAt,
  }) {
    return QuoteModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      pageIndex: pageIndex ?? this.pageIndex,
      text: text ?? this.text,
      normalizedTop: normalizedTop ?? this.normalizedTop,
      normalizedBottom: normalizedBottom ?? this.normalizedBottom,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}