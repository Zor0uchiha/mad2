import "package:hive/hive.dart";

@HiveType(typeId: 5)
class ReadingListModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? coverUrl;

  @HiveField(4)
  String userId;

  @HiveField(5)
  List<String> bookIds;

  @HiveField(6)
  bool isPublic;

  @HiveField(7)
  int sortOrder;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  ReadingListModel({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    required this.userId,
    this.bookIds = const [],
    this.isPublic = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  int get bookCount => bookIds.length;

  ReadingListModel copyWith({
    String? id,
    String? title,
    String? description,
    String? coverUrl,
    String? userId,
    List<String>? bookIds,
    bool? isPublic,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReadingListModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      userId: userId ?? this.userId,
      bookIds: bookIds ?? this.bookIds,
      isPublic: isPublic ?? this.isPublic,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
