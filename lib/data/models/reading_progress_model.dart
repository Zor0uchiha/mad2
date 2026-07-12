import "package:hive/hive.dart";

@HiveType(typeId: 8)
class ReadingProgressModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String bookId;

  @HiveField(2)
  int currentPage;

  @HiveField(3)
  double progressPercentage;

  @HiveField(4)
  int? totalPages;

  @HiveField(5)
  DateTime lastReadAt;

  @HiveField(6)
  int? readingTimeMinutes;

  ReadingProgressModel({
    required this.id,
    required this.bookId,
    this.currentPage = 0,
    this.progressPercentage = 0.0,
    this.totalPages,
    required this.lastReadAt,
    this.readingTimeMinutes,
  });
}
