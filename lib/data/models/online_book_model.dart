import "package:json_annotation/json_annotation.dart";

part "online_book_model.g.dart";

@JsonSerializable()
class OnlineBookModel {
  final String id;
  final String title;
  final List<String> authors;
  final String? description;
  final String? thumbnail;
  final int? pageCount;
  final String? publisher;
  final String? publishedDate;
  final List<String> categories;
  final String? language;
  final String? isbn;
  final double? averageRating;
  final int? ratingsCount;

  const OnlineBookModel({
    required this.id,
    required this.title,
    this.authors = const [],
    this.description,
    this.thumbnail,
    this.pageCount,
    this.publisher,
    this.publishedDate,
    this.categories = const [],
    this.language,
    this.isbn,
    this.averageRating,
    this.ratingsCount,
  });

  factory OnlineBookModel.fromJson(Map<String, dynamic> json) =>
      _$OnlineBookModelFromJson(json);

  Map<String, dynamic> toJson() => _$OnlineBookModelToJson(this);
}
