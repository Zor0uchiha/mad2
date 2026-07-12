import "package:hive/hive.dart";

@HiveType(typeId: 9)
class ReadingGoalModel extends HiveObject {
  @HiveField(0)
  int booksPerYear;

  @HiveField(1)
  int pagesPerYear;

  @HiveField(2)
  int minutesPerDay;

  @HiveField(3)
  DateTime updatedAt;

  ReadingGoalModel({
    this.booksPerYear = 12,
    this.pagesPerYear = 3650,
    this.minutesPerDay = 20,
    required this.updatedAt,
  });

  ReadingGoalModel copyWith({
    int? booksPerYear,
    int? pagesPerYear,
    int? minutesPerDay,
    DateTime? updatedAt,
  }) {
    return ReadingGoalModel(
      booksPerYear: booksPerYear ?? this.booksPerYear,
      pagesPerYear: pagesPerYear ?? this.pagesPerYear,
      minutesPerDay: minutesPerDay ?? this.minutesPerDay,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
