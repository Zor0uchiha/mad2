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

  factory OnlineBookModel.fromJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>? ?? [];
    final isbn13 = identifiers.cast<Map<String, dynamic>?>().firstWhere(
          (id) => id != null && id['type'] == 'ISBN_13',
          orElse: () => null,
        );

    return OnlineBookModel(
      id: json['id'] as String? ?? '',
      title: volumeInfo['title'] as String? ?? 'Unknown Title',
      authors: (volumeInfo['authors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      description: volumeInfo['description'] as String?,
      thumbnail: (volumeInfo['imageLinks'] as Map<String, dynamic>?)?['thumbnail'] as String?,
      pageCount: volumeInfo['pageCount'] as int?,
      publisher: volumeInfo['publisher'] as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      categories: (volumeInfo['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      language: volumeInfo['language'] as String?,
      isbn: isbn13?['identifier'] as String?,
      averageRating: (volumeInfo['averageRating'] as num?)?.toDouble(),
      ratingsCount: volumeInfo['ratingsCount'] as int?,
    );
  }
}
