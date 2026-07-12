class ReviewModel {
  String id;
  String userId;
  String userName;
  String bookId;
  String bookTitle;
  String? bookCoverUrl;
  double rating;
  String text;
  bool hasSpoiler;
  List<String> tags;
  DateTime? readingDate;
  bool isPublic;
  DateTime createdAt;
  DateTime updatedAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.bookId,
    this.bookTitle = '',
    this.bookCoverUrl,
    this.rating = 0,
    this.text = '',
    this.hasSpoiler = false,
    this.tags = const [],
    this.readingDate,
    this.isPublic = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ReviewModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? bookId,
    String? bookTitle,
    String? bookCoverUrl,
    double? rating,
    String? text,
    bool? hasSpoiler,
    List<String>? tags,
    DateTime? readingDate,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookCoverUrl: bookCoverUrl ?? this.bookCoverUrl,
      rating: rating ?? this.rating,
      text: text ?? this.text,
      hasSpoiler: hasSpoiler ?? this.hasSpoiler,
      tags: tags ?? this.tags,
      readingDate: readingDate ?? this.readingDate,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
