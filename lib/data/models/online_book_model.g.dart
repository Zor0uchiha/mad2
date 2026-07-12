part of "online_book_model.dart";

OnlineBookModel _$OnlineBookModelFromJson(Map<String, dynamic> json) {
  return OnlineBookModel(
    id: json['id'] as String,
    title: json['title'] as String,
    authors: (json['authors'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    description: json['description'] as String?,
    thumbnail: json['thumbnail'] as String?,
    pageCount: json['pageCount'] as int?,
    publisher: json['publisher'] as String?,
    publishedDate: json['publishedDate'] as String?,
    categories: (json['categories'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    language: json['language'] as String?,
    isbn: json['isbn'] as String?,
    averageRating: (json['averageRating'] as num?)?.toDouble(),
    ratingsCount: json['ratingsCount'] as int?,
  );
}

Map<String, dynamic> _$OnlineBookModelToJson(OnlineBookModel instance) {
  final Map<String, dynamic> json = <String, dynamic>{};
  json['id'] = instance.id;
  json['title'] = instance.title;
  json['authors'] = instance.authors;
  json['description'] = instance.description;
  json['thumbnail'] = instance.thumbnail;
  json['pageCount'] = instance.pageCount;
  json['publisher'] = instance.publisher;
  json['publishedDate'] = instance.publishedDate;
  json['categories'] = instance.categories;
  json['language'] = instance.language;
  json['isbn'] = instance.isbn;
  json['averageRating'] = instance.averageRating;
  json['ratingsCount'] = instance.ratingsCount;
  return json;
}
