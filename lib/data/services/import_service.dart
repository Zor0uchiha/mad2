import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/book_model.dart';
import '../repositories/book_repository.dart';

class ImportService {
  final BookRepository _bookRepo;

  ImportService(this._bookRepo);

  Future<List<BookModel>> pickAndImportBooks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return [];

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'libora_books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final imported = <BookModel>[];
    for (final file in result.files) {
      if (file.path == null) continue;

      final source = File(file.path!);
      final ext = p.extension(file.name).toLowerCase();
      final format = ext == '.epub' ? BookFormat.epub : BookFormat.pdf;
      final bookId = const Uuid().v4();
      final destName = '$bookId$ext';
      final destPath = p.join(booksDir.path, destName);

      await source.copy(destPath);

      final title = _extractTitle(file.name);
      final author = _extractAuthor(file.name);

      final book = BookModel(
        id: bookId,
        title: title,
        author: author,
        filePath: destPath,
        format: format,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _bookRepo.addBook(book);
      imported.add(book);
    }

    return imported;
  }

  String _extractTitle(String filename) {
    final name = p.basenameWithoutExtension(filename);
    return name.replaceAll(RegExp(r'[_-]'), ' ').trim();
  }

  String _extractAuthor(String filename) {
    final parts = p.basenameWithoutExtension(filename).split(RegExp(r'[_-]'));
    if (parts.length >= 2) {
      return parts.sublist(0, parts.length ~/ 2).join(' ').trim();
    }
    return 'Unknown Author';
  }
}
