class OnlineBookModel {
  final String id;
  final String source;
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
  final String? isbn10;
  final double? averageRating;
  final int? ratingsCount;
  final String? previewLink;
  final String? infoLink;
  final String? downloadLink;
  final String? epubDownloadLink;
  final String? pdfDownloadLink;
  final String? readOnlineLink;
  final String? borrowLink;
  final String? buyLink;
  final bool isPublicDomain;
  final bool isFree;
  final int? downloadCount;

  const OnlineBookModel({
    required this.id,
    required this.source,
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
    this.isbn10,
    this.averageRating,
    this.ratingsCount,
    this.previewLink,
    this.infoLink,
    this.downloadLink,
    this.epubDownloadLink,
    this.pdfDownloadLink,
    this.readOnlineLink,
    this.borrowLink,
    this.buyLink,
    this.isPublicDomain = false,
    this.isFree = false,
    this.downloadCount,
  });

  factory OnlineBookModel.fromGoogleBooks(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>? ?? [];
    String? isbn13;
    String? isbn10;
    for (final id in identifiers) {
      final map = id as Map<String, dynamic>;
      if (map['type'] == 'ISBN_13') isbn13 = map['identifier'] as String?;
      if (map['type'] == 'ISBN_10') isbn10 = map['identifier'] as String?;
    }
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    final accessInfo = json['accessInfo'] as Map<String, dynamic>?;
    final saleInfo = json['saleInfo'] as Map<String, dynamic>?;
    final isFree = saleInfo?['saleability'] == 'FREE' ||
        (saleInfo?['saleability'] == 'FOR_SALE' &&
            (saleInfo?['listPrice']?['amount'] ?? 0) == 0);

    return OnlineBookModel(
      id: json['id'] as String? ?? '',
      source: 'google_books',
      title: volumeInfo['title'] as String? ?? 'Unknown Title',
      authors: (volumeInfo['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: _sanitize(volumeInfo['description'] as String?),
      thumbnail: imageLinks?['thumbnail'] as String?,
      pageCount: volumeInfo['pageCount'] as int?,
      publisher: volumeInfo['publisher'] as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      categories: (volumeInfo['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      language: volumeInfo['language'] as String?,
      isbn: isbn13,
      isbn10: isbn10,
      averageRating: (volumeInfo['averageRating'] as num?)?.toDouble(),
      ratingsCount: volumeInfo['ratingsCount'] as int?,
      previewLink: volumeInfo['previewLink'] as String?,
      infoLink: volumeInfo['infoLink'] as String?,
      buyLink: saleInfo?['buyLink'] as String?,
      isFree: isFree,
      isPublicDomain: accessInfo?['publicDomain'] == true,
    );
  }

  factory OnlineBookModel.fromOpenLibrary(Map<String, dynamic> json) {
    final coverId = json['cover_i'];
    final coverUrl =
        coverId != null ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg' : null;
    final key = json['key'] as String? ?? '';

    return OnlineBookModel(
      id: key,
      source: 'open_library',
      title: json['title'] as String? ?? 'Unknown Title',
      authors: (json['author_name'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      thumbnail: coverUrl,
      pageCount: json['number_of_pages_median'] as int?,
      publishedDate: json['first_publish_year']?.toString(),
      categories: (json['subject'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      language: _firstString(json['language']),
      isbn: _firstString(json['isbn']),
      averageRating: (json['ratings_average'] as num?)?.toDouble(),
      ratingsCount: json['ratings_count'] as int?,
      downloadCount: json['download_count'] as int?,
      borrowLink: 'https://openlibrary.org$key/borrow',
      readOnlineLink: 'https://openlibrary.org$key',
      isPublicDomain: json['public_scan'] == true,
      isFree: true,
    );
  }

  factory OnlineBookModel.fromGutendex(Map<String, dynamic> json) {
    final formats = json['formats'] as Map<String, dynamic>? ?? {};
    final authorsList = (json['authors'] as List<dynamic>?) ?? [];
    final authorNames = authorsList
        .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? 'Unknown')
        .toList();
    final subjects = (json['subjects'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final bookshelves = (json['bookshelves'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final langs = (json['languages'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return OnlineBookModel(
      id: 'gutendex_${json['id']}',
      source: 'gutendex',
      title: json['title'] as String? ?? 'Unknown Title',
      authors: authorNames,
      description: subjects.isNotEmpty ? subjects.take(3).join('. ') : null,
      thumbnail: formats['image/jpeg'] as String?,
      pageCount: (json['download_count'] as int?) != null
          ? (json['download_count'] as int) ~/ 100
          : null,
      categories: [...subjects, ...bookshelves],
      language: langs.isNotEmpty ? langs.first : null,
      isbn: json['id']?.toString(),
      downloadCount: json['download_count'] as int?,
      epubDownloadLink: formats['application/epub+zip'] as String?,
      pdfDownloadLink: formats['application/pdf'] as String?,
      readOnlineLink: formats['text/html'] as String?,
      downloadLink: formats['application/epub+zip'] as String?,
      isPublicDomain: json['copyright'] == false || json['copyright'] == null,
      isFree: true,
    );
  }

  factory OnlineBookModel.fromStorageJson(Map<String, dynamic> json) {
    return OnlineBookModel(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String?,
      thumbnail: json['thumbnail'] as String?,
      pageCount: json['pageCount'] as int?,
      publisher: json['publisher'] as String?,
      publishedDate: json['publishedDate'] as String?,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      language: json['language'] as String?,
      isbn: json['isbn'] as String?,
      isbn10: json['isbn10'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      ratingsCount: json['ratingsCount'] as int?,
      previewLink: json['previewLink'] as String?,
      infoLink: json['infoLink'] as String?,
      downloadLink: json['downloadLink'] as String?,
      epubDownloadLink: json['epubDownloadLink'] as String?,
      pdfDownloadLink: json['pdfDownloadLink'] as String?,
      readOnlineLink: json['readOnlineLink'] as String?,
      borrowLink: json['borrowLink'] as String?,
      buyLink: json['buyLink'] as String?,
      isPublicDomain: json['isPublicDomain'] == true,
      isFree: json['isFree'] == true,
      downloadCount: json['downloadCount'] as int?,
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'source': source,
      'title': title,
      'authors': authors,
      'description': description,
      'thumbnail': thumbnail,
      'pageCount': pageCount,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'categories': categories,
      'language': language,
      'isbn': isbn,
      'isbn10': isbn10,
      'averageRating': averageRating,
      'ratingsCount': ratingsCount,
      'previewLink': previewLink,
      'infoLink': infoLink,
      'downloadLink': downloadLink,
      'epubDownloadLink': epubDownloadLink,
      'pdfDownloadLink': pdfDownloadLink,
      'readOnlineLink': readOnlineLink,
      'borrowLink': borrowLink,
      'buyLink': buyLink,
      'isPublicDomain': isPublicDomain,
      'isFree': isFree,
      'downloadCount': downloadCount,
    };
  }

  static String? _sanitize(String? text) {
    if (text == null) return null;
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  static String? _firstString(dynamic list) {
    if (list is List && list.isNotEmpty) return list[0].toString();
    return null;
  }
}
