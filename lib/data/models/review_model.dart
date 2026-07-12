import "package:hive/hive.dart";

part "review_model.g.dart";

@HiveType(typeId: 4)
class ReviewModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String userName;

  @HiveField(3)
  String bookId;

  @HiveField(4)
  double rating;

  @HiveField(5)
  String text;

  @HiveField(6)
  bool hasSpoiler;

  @HiveField(7)
  List<String> tags;

  @HiveField(8)
  DateTime? readingDate;

  @HiveField(9)
  bool isPublic;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime updatedAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.bookId,
    this.rating = 0,
    this.text = "",
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
