enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  orange,
  purple;

  static HighlightColor fromName(String? name) {
    for (final c in HighlightColor.values) {
      if (c.name == name) return c;
    }
    return HighlightColor.yellow;
  }
}

class HighlightModel {
  String id;
  String bookId;
  String bookTitle;
  String chapterName;
  int pageIndex;
  String text;
  String? note;
  HighlightColor color;
  bool underlined;
  DateTime createdAt;
  DateTime updatedAt;

  HighlightModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.chapterName = "",
    required this.pageIndex,
    required this.text,
    this.note,
    this.color = HighlightColor.yellow,
    this.underlined = false,
    required this.createdAt,
    required this.updatedAt,
  });

  HighlightModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? chapterName,
    int? pageIndex,
    String? text,
    String? note,
    HighlightColor? color,
    bool? underlined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HighlightModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterName: chapterName ?? this.chapterName,
      pageIndex: pageIndex ?? this.pageIndex,
      text: text ?? this.text,
      note: note ?? this.note,
      color: color ?? this.color,
      underlined: underlined ?? this.underlined,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Map<HighlightColor, int> highlightColorValues = {
  HighlightColor.yellow: 0xFFFFEB3B,
  HighlightColor.green: 0xFF4CAF50,
  HighlightColor.blue: 0xFF2196F3,
  HighlightColor.pink: 0xFFF06292,
  HighlightColor.orange: 0xFFFF9800,
  HighlightColor.purple: 0xFF9C27B0,
};
