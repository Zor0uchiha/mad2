class ReadingProgressModel {
  String id;
  String bookId;
  int currentPage;
  double progressPercentage;
  int? totalPages;
  DateTime lastReadAt;
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
