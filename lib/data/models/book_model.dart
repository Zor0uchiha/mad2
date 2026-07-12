enum BookFormat {
  pdf,
  epub;

  String get displayName => name.toUpperCase();

  static BookFormat fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pdf':
        return BookFormat.pdf;
      case 'epub':
        return BookFormat.epub;
      default:
        return BookFormat.pdf;
    }
  }
}

class BookModel {
  String id;
  String title;
  String author;
  String? description;
  String? coverPath;
  String? filePath;
  BookFormat format;
  int pageCount;
  int currentPage;
  double progress;
  List<String> tags;
  bool isFavorite;
  DateTime? lastOpenedAt;
  DateTime createdAt;
  DateTime updatedAt;
  String? isbn;
  String? publisher;
  String? language;
  DateTime? publishedDate;
  List<String> collectionIds;
  String? onlineBookId;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    this.coverPath,
    this.filePath,
    required this.format,
    this.pageCount = 0,
    this.currentPage = 0,
    this.progress = 0.0,
    this.tags = const [],
    this.isFavorite = false,
    this.lastOpenedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isbn,
    this.publisher,
    this.language,
    this.publishedDate,
    this.collectionIds = const [],
    this.onlineBookId,
  });

  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? coverPath,
    String? filePath,
    BookFormat? format,
    int? pageCount,
    int? currentPage,
    double? progress,
    List<String>? tags,
    bool? isFavorite,
    DateTime? lastOpenedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? isbn,
    String? publisher,
    String? language,
    DateTime? publishedDate,
    List<String>? collectionIds,
    String? onlineBookId,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      pageCount: pageCount ?? this.pageCount,
      currentPage: currentPage ?? this.currentPage,
      progress: progress ?? this.progress,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isbn: isbn ?? this.isbn,
      publisher: publisher ?? this.publisher,
      language: language ?? this.language,
      publishedDate: publishedDate ?? this.publishedDate,
      collectionIds: collectionIds ?? this.collectionIds,
      onlineBookId: onlineBookId ?? this.onlineBookId,
    );
  }
}
