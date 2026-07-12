class ReadingGoalModel {
  String id;
  int targetBooks;
  int targetPages;
  int targetMinutes;
  DateTime startDate;
  DateTime endDate;
  int currentBooks;
  int currentPages;
  int currentMinutes;

  ReadingGoalModel({
    required this.id,
    this.targetBooks = 0,
    this.targetPages = 0,
    this.targetMinutes = 0,
    required this.startDate,
    required this.endDate,
    this.currentBooks = 0,
    this.currentPages = 0,
    this.currentMinutes = 0,
  });

  double get booksProgress => targetBooks > 0 ? currentBooks / targetBooks : 0;
  double get pagesProgress => targetPages > 0 ? currentPages / targetPages : 0;
  double get minutesProgress => targetMinutes > 0 ? currentMinutes / targetMinutes : 0;
  double get overallProgress => (booksProgress + pagesProgress + minutesProgress) / 3;
}
