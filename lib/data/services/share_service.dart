import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareImage(GlobalKey repaintKey, {String? text}) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(pngBytes, name: 'bookstr_share.png')],
        text: text ?? '',
      );
    } catch (e) {
      await Share.share(text ?? '');
    }
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  static Future<void> shareBook(String title, String author, {String? coverUrl}) async {
    final text = 'Reading "$title" by $author on Bookstr';
    await shareText(text);
  }

  static Future<void> shareReview(String bookTitle, double rating, String review) async {
    final stars = '★' * rating.round() + '☆' * (5 - rating.round());
    final text = 'Reviewed "$bookTitle" $stars\n\n$review\n\nvia Bookstr';
    await shareText(text);
  }

  static Future<void> shareReadingList(String listName, List<String> books) async {
    final bookList = books.take(5).map((b) => '• $b').join('\n');
    final text = 'My reading list: "$listName"\n\n$bookList\n\nvia Bookstr';
    await shareText(text);
  }

  static Future<void> shareStatistics({
    required int booksRead,
    required int pagesRead,
    required int readingTime,
    required int streak,
  }) async {
    final text = '📚 Bookstr Reading Stats\n\n'
        'Books Read: $booksRead\n'
        'Pages Read: $pagesRead\n'
        'Reading Time: ${readingTime}m\n'
        'Streak: $streak days\n\n'
        'via Bookstr';
    await shareText(text);
  }
}
