import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

enum EpubBlockType { heading, paragraph, blockquote, listItem, image, table, divider, preformatted }

class EpubInline {
  final String text;
  final bool bold;
  final bool italic;
  final String? href;
  final bool footnote;

  const EpubInline({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.href,
    this.footnote = false,
  });
}

class EpubBlock {
  final EpubBlockType type;
  final int level;
  final List<EpubInline> inlines;
  final String? imageKey;
  final List<List<String>> tableRows;

  const EpubBlock({
    required this.type,
    this.level = 1,
    this.inlines = const [],
    this.imageKey,
    this.tableRows = const [],
  });

  String get text => inlines.map((i) => i.text).join();
}

class EpubChapterData {
  final String title;
  final String filePath;
  final List<EpubBlock> blocks;
  final Map<String, Uint8List> images;
  final html_dom.Document document;

  const EpubChapterData({
    required this.title,
    required this.filePath,
    required this.blocks,
    required this.images,
    required this.document,
  });

  String get plainText {
    final buf = StringBuffer();
    for (final b in blocks) {
      if (b.type == EpubBlockType.heading ||
          b.type == EpubBlockType.paragraph ||
          b.type == EpubBlockType.blockquote ||
          b.type == EpubBlockType.listItem ||
          b.type == EpubBlockType.preformatted) {
        buf.writeln(b.text);
      }
    }
    return buf.toString();
  }
}

class ParsedEpub {
  final String title;
  final String author;
  final List<EpubChapterData> chapters;

  const ParsedEpub({required this.title, required this.author, required this.chapters});
}

class EpubParser {
  static Future<ParsedEpub?> parseFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return parseBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<ParsedEpub?> parseBytes(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive == null) return null;
      final files = <String, Uint8List>{};
      for (final f in archive) {
        if (f.isFile) files[f.name] = _toBytes(f.content);
      }

      final container = files['META-INF/container.xml'];
      if (container == null) return null;
      final containerDoc = html_parser.parse(utf8.decode(container));
      final rootfile = containerDoc.querySelector('rootfile')?.attributes['full-path'];
      if (rootfile == null) return null;

      final opfPath = _normalizePath(rootfile);
      final opfBytes = files[opfPath];
      if (opfBytes == null) return null;
      final opfDoc = html_parser.parse(utf8.decode(opfBytes));

      final title = _queryText(opfDoc, 'dc\\:title') ?? _queryText(opfDoc, 'title') ?? 'Untitled';
      final author = _queryText(opfDoc, 'dc\\:creator') ?? _queryText(opfDoc, 'creator') ?? 'Unknown Author';

      final manifest = <String, String>{};
      for (final m in opfDoc.querySelectorAll('manifest item')) {
        final id = m.attributes['id'] ?? '';
        final href = m.attributes['href'] ?? '';
        if (id.isNotEmpty && href.isNotEmpty) manifest[id] = href;
      }

      final spineItems = <String>[];
      for (final s in opfDoc.querySelectorAll('spine itemref')) {
        final href = manifest[s.attributes['idref'] ?? ''];
        if (href != null) spineItems.add(href);
      }
      if (spineItems.isEmpty) {
        manifest.values
            .where((h) => _isHtmlFile(h))
            .toList()
            .forEach(spineItems.add);
      }

      final baseDir = _dirname(opfPath);
      final chapters = <EpubChapterData>[];
      for (final item in spineItems) {
        final href = _normalizePath('$baseDir/$item');
        final raw = files[href];
        if (raw == null) continue;
        final doc = html_parser.parse(utf8.decode(raw));
        final chapterTitle = _queryText(doc, 'title') ?? 'Chapter ${chapters.length + 1}';
        chapters.add(_buildChapter(chapterTitle, href, doc, files));
      }

      if (chapters.isEmpty) return null;
      return ParsedEpub(title: title, author: author, chapters: chapters);
    } catch (_) {
      return null;
    }
  }

  static EpubChapterData _buildChapter(
    String title,
    String filePath,
    html_dom.Document doc,
    Map<String, Uint8List> files,
  ) {
    final images = <String, Uint8List>{};
    final blocks = <EpubBlock>[];
    final body = doc.body;
    if (body != null) {
      _walkChildren(body, blocks, filePath, files, images);
    }
    return EpubChapterData(
      title: title,
      filePath: filePath,
      blocks: blocks,
      images: images,
      document: doc,
    );
  }

  static void _walkChildren(
    html_dom.Element parent,
    List<EpubBlock> blocks,
    String chapterHref,
    Map<String, Uint8List> files,
    Map<String, Uint8List> images,
  ) {
    for (final child in parent.children) {
      _handleElement(child, blocks, chapterHref, files, images);
    }
  }

  static void _handleElement(
    html_dom.Element el,
    List<EpubBlock> blocks,
    String chapterHref,
    Map<String, Uint8List> files,
    Map<String, Uint8List> images,
  ) {
    final tag = el.localName ?? '';
    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        blocks.add(EpubBlock(type: EpubBlockType.heading, level: int.tryParse(tag.substring(1)) ?? 1, inlines: _inlines(el)));
        break;
      case 'p':
        final inlines = _inlines(el);
        if (inlines.isNotEmpty) blocks.add(EpubBlock(type: EpubBlockType.paragraph, inlines: inlines));
        break;
      case 'blockquote':
        final inlines = _inlines(el);
        if (inlines.isNotEmpty) blocks.add(EpubBlock(type: EpubBlockType.blockquote, inlines: inlines));
        break;
      case 'ul':
      case 'ol':
        for (final li in el.children.where((c) => c.localName == 'li')) {
          final inlines = _inlines(li);
          if (inlines.isNotEmpty) blocks.add(EpubBlock(type: EpubBlockType.listItem, inlines: inlines));
        }
        break;
      case 'img':
        _addImage(el, blocks, chapterHref, files, images);
        break;
      case 'figure':
        final imgEl = el.querySelector('img');
        if (imgEl != null) _addImage(imgEl, blocks, chapterHref, files, images);
        final caption = el.querySelector('figcaption');
        if (caption != null) {
          final inlines = _inlines(caption);
          if (inlines.isNotEmpty) blocks.add(EpubBlock(type: EpubBlockType.paragraph, level: 3, inlines: inlines));
        }
        break;
      case 'table':
        final rows = <List<String>>[];
        for (final tr in el.querySelectorAll('tr')) {
          rows.add(tr.children.map((c) => c.text.trim()).toList());
        }
        if (rows.isNotEmpty) blocks.add(EpubBlock(type: EpubBlockType.table, tableRows: rows));
        break;
      case 'hr':
        blocks.add(const EpubBlock(type: EpubBlockType.divider));
        break;
      case 'pre':
        final inlines = _inlines(el);
        if (inlines.isNotEmpty) blocks.add(EpubBlock(type: EpubBlockType.preformatted, inlines: inlines));
        break;
      case 'div':
      case 'section':
      case 'article':
      case 'main':
        _walkChildren(el, blocks, chapterHref, files, images);
        break;
      case 'nav':
        break;
      default:
        final inlines = _inlines(el);
        if (inlines.isNotEmpty) {
          blocks.add(EpubBlock(type: EpubBlockType.paragraph, inlines: inlines));
        }
        break;
    }
  }

  static void _addImage(
    html_dom.Element imgEl,
    List<EpubBlock> blocks,
    String chapterHref,
    Map<String, Uint8List> files,
    Map<String, Uint8List> images,
  ) {
    final src = imgEl.attributes['src'] ?? '';
    if (src.isEmpty) return;
    final bytes = _resolveImage(src, chapterHref, files);
    if (bytes == null) return;
    blocks.add(EpubBlock(type: EpubBlockType.image, imageKey: src));
    images[src] = bytes;
  }

  static Uint8List? _resolveImage(String src, String chapterHref, Map<String, Uint8List> files) {
    final uri = Uri.tryParse(src);
    if (uri == null) return null;
    if (uri.scheme == 'data') return null;
    if (uri.hasScheme) return null;
    final resolvedPath = Uri.parse(chapterHref).resolve(uri.toString()).path;
    return files[_normalizePath(resolvedPath)];
  }

  static List<EpubInline> _inlines(
    html_dom.Element el, {
    bool bold = false,
    bool italic = false,
    String? href,
  }) {
    final result = <EpubInline>[];
    for (final node in el.nodes) {
      if (node is html_dom.Text) {
        final t = node.text;
        if (t.isNotEmpty) result.add(EpubInline(text: t, bold: bold, italic: italic, href: href));
      } else if (node is html_dom.Element) {
        final tag = node.localName ?? '';
        final isBold = bold || tag == 'b' || tag == 'strong';
        final isItalic = italic || tag == 'i' || tag == 'em';
        if (tag == 'br') {
          result.add(EpubInline(text: '\n', bold: bold, italic: italic, href: href));
        } else if (tag == 'sup' || tag == 'sub') {
          final a = node.querySelector('a');
          final innerHref = a?.attributes['href'];
          final t = (a ?? node).text.trim();
          if (t.isNotEmpty) {
            result.add(EpubInline(text: t, bold: bold, italic: italic, href: innerHref ?? href, footnote: innerHref != null));
          }
        } else if (tag == 'a') {
          result.addAll(_inlines(node, bold: bold, italic: italic, href: node.attributes['href'] ?? href));
        } else {
          result.addAll(_inlines(node, bold: isBold, italic: isItalic, href: href));
        }
      }
    }
    return result;
  }

  static String? _queryText(html_dom.Document doc, String selector) {
    final el = doc.querySelector(selector);
    if (el == null) return null;
    final t = el.text.trim();
    return t.isEmpty ? null : t;
  }

  static String _normalizePath(String path) {
    var p = path.replaceAll('\\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  static String _dirname(String path) {
    final idx = path.lastIndexOf('/');
    return idx <= 0 ? '' : path.substring(0, idx);
  }

  static bool _isHtmlFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.html') || lower.endsWith('.xhtml') || lower.endsWith('.htm');
  }

  static Uint8List _toBytes(dynamic content) {
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    if (content is String) return Uint8List.fromList(utf8.encode(content));
    return Uint8List(0);
  }
}
