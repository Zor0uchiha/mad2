import "dart:io";
import "package:file_picker/file_picker.dart";
import "package:file/file.dart" as fs;
import "package:epub_view/epub_view.dart";
import "package:path/path.dart" as p;
import "../../core/errors/app_exception.dart";
import "../../core/utils/logger.dart";

class BookImportService {
  Future<BookImportResult> importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf", "epub"],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return BookImportResult(success: false, error: "No file selected");
    }

    final file = result.files.first;
    final path = file.path;
    final fileName = file.name;
    final extension = p.extension(fileName).toLowerCase();

    if (extension != ".pdf" && extension != ".epub") {
      return BookImportResult(success: false, error: "Unsupported file format");
    }

    return BookImportResult(
      success: true,
      filePath: path,
      fileName: fileName,
      format: extension == ".pdf" ? BookFormat.pdf : BookFormat.epub,
    );
  }
}

class BookImportResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final BookFormat? format;
  final String? error;

  BookImportResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.format,
    this.error,
  });
}
