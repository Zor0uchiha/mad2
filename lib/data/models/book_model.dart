import "package:hive/hive.dart";

part "book_model.g.dart";

@HiveType(typeId: 0)
enum BookFormat {
  @HiveField(0)
  pdf,
  @HiveField(1)
  epub;

  String get displayName => name.toUpperCase();
}

@HiveType(typeId: 1)
class BookModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String author;

  @HiveField(3)
  String? description;

  @HiveField(4)
  String? coverPath;

  @HiveField(5)
  String? filePath;

  @HiveField(6)
  BookFormat format;

  @HiveField(7)
  int pageCount;

  @HiveField(8)
  int currentPage;

  @HiveField(9)
  double progress;

  @HiveField(10)
  List<String> tags;

  @HiveField(11)
  bool isFavorite;

  @HiveField(12)
  DateTime? lastOpenedAt;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  DateTime updatedAt;

  @HiveField(15)
  String? isbn;

  @HiveField(16)
  String? publisher;

  @HiveField(17)
  String? language;

  @HiveField(18)
  DateTime? publishedDate;

  @HiveField(19)
  List<String> collectionIds;

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
    );
  }
}
