import "dart:ui";
import "package:share_plus/share_plus.dart";

class ShareService {
  static Future<void> shareImage(Uint8List imageBytes, String text) async {
    final tempDir = Directory.systemTemp;
    final file = File("${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png");
    await file.writeAsBytes(imageBytes);
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
