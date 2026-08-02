import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import 'highlight_model.dart';

class HighlightRepository {
  Box<HighlightModel>? _box;

  Future<Box<HighlightModel>> get _boxAsync async {
    _box ??= await Hive.openBox<HighlightModel>(AppConstants.hiveBoxHighlights);
    return _box!;
  }

  Future<void> saveHighlight(HighlightModel highlight) async {
    final box = await _boxAsync;
    if (highlight.id.isEmpty) {
      highlight.id = DateTime.now().millisecondsSinceEpoch.toString();
    }
    highlight.updatedAt = DateTime.now();
    await box.put(highlight.id, highlight);
  }

  Future<void> deleteHighlight(String id) async {
    final box = await _boxAsync;
    await box.delete(id);
  }

  Future<HighlightModel?> getHighlight(String id) async {
    final box = await _boxAsync;
    return box.get(id);
  }

  Future<List<HighlightModel>> getHighlightsForBook(String bookId) async {
    final box = await _boxAsync;
    final list = box.values.where((h) => h.bookId == bookId).toList();
    list.sort((a, b) {
      if (a.chapterName != b.chapterName) return a.chapterName.compareTo(b.chapterName);
      return a.pageIndex.compareTo(b.pageIndex);
    });
    return list;
  }

  Future<List<HighlightModel>> getAllHighlights() async {
    final box = await _boxAsync;
    final list = box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
