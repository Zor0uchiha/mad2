import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';

class ReaderAiTools {
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsInit = false;

  static Future<void> _initTts() async {
    if (_ttsInit) return;
    _ttsInit = true;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  static Future<void> speak(String text) async {
    await _initTts();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static Future<String> dictionaryLookup(String word) async {
    final clean = word.trim().split(RegExp(r'\s+')).first.toLowerCase();
    try {
      final res = await http
          .get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$clean'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return "No dictionary entry found for \"$clean\".";
      }
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return "No dictionary entry found for \"$clean\".";
      final entry = data.first as Map<String, dynamic>;
      final wordTitle = entry['word'] ?? clean;
      final phonetics = entry['phonetic'] ?? '';
      final meanings = entry['meanings'] as List? ?? [];
      final buf = StringBuffer('**$wordTitle**');
      if (phonetics.toString().isNotEmpty) buf.write('  /$phonetics/');
      for (final m in meanings.take(3)) {
        final part = m['partOfSpeech'] ?? '';
        final defs = (m['definitions'] as List? ?? []);
        buf.writeln();
        buf.writeln('_$part_');
        var count = 0;
        for (final d in defs) {
          if (count >= 3) break;
          final definition = d['definition'] ?? '';
          final example = d['example'];
          buf.writeln('• $definition');
          if (example != null && example.toString().isNotEmpty) {
            buf.writeln('  e.g. "$example"');
          }
          count++;
        }
      }
      return buf.toString();
    } catch (_) {
      return "Couldn't reach the dictionary. Check your connection and try again.";
    }
  }

  static Future<String> translateText(String text, {required String toLang}) async {
    try {
      final uri = Uri.parse('https://api.mymemory.translated.net/get').replace(
        queryParameters: {
          'q': text,
          'langpair': 'en|$toLang',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return "Translation failed (${res.statusCode}).";
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final matched = data['responseData'];
      final translated = matched is Map ? matched['translatedText'] as String? : null;
      if (translated == null) return "Translation failed.";
      return translated.replaceAll('&#39;', "'").replaceAll('&quot;', '"');
    } catch (_) {
      return "Couldn't reach the translation service. Check your connection.";
    }
  }

  static String localExplain(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return "Select some text first.";
    final sentences = _sentences(clean);
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final stop = {
      'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'at',
      'for', 'with', 'is', 'are', 'was', 'were', 'be', 'been', 'this', 'that',
      'it', 'as', 'by', 'from', 'has', 'have', 'had', 'not', 'no', 'its',
    };
    final content = words.where((w) => !stop.contains(w.toLowerCase())).toList();
    final freq = <String, int>{};
    for (final w in content) {
      final key = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key.length < 3) continue;
      freq[key] = (freq[key] ?? 0) + 1;
    }
    final top = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final keyTerms = top.take(5).map((e) => e.key).toList();

    final buf = StringBuffer();
    buf.writeln('Here is a quick offline explanation of the selected passage:');
    buf.writeln();
    buf.writeln('• It is ${sentences.length} sentence${sentences.length == 1 ? "" : "s"} long and contains ${words.length} words.');
    buf.writeln('• The main idea appears to revolve around the key term${keyTerms.length == 1 ? "" : "s"}: '
        '${keyTerms.join(", ")}.');
    buf.writeln('• Reading it carefully, the passage ${_toneGuess(clean)}.');
    buf.writeln();
    buf.writeln('For a richer explanation with deeper context, an online AI service can be connected later — '
        'this offline summary keeps reading fast and private.');
    return buf.toString();
  }

  static String localSummarize(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return "Select some text first.";
    final sentences = _sentences(clean);
    if (sentences.length <= 2) {
      return "The passage is short enough to read directly:\n\n$clean";
    }
    final stop = {
      'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'at', 'for',
      'with', 'is', 'are', 'was', 'were', 'be', 'been', 'this', 'that', 'it', 'as',
      'by', 'from', 'has', 'have', 'had', 'not', 'no', 'its', 'their', 'they',
    };
    final freq = <String, int>{};
    for (final s in sentences) {
      for (final w in s.split(RegExp(r'\s+'))) {
        final key = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (key.length < 3 || stop.contains(key)) continue;
        freq[key] = (freq[key] ?? 0) + 1;
      }
    }
    String score(String s) {
      var total = 0;
      for (final w in s.split(RegExp(r'\s+'))) {
        final key = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        total += freq[key] ?? 0;
      }
      return total / (s.split(RegExp(r'\s+')).length + 1);
    }

    final ranked = sentences.toList()..sort((a, b) => score(b).compareTo(score(a)));
    final buf = StringBuffer();
    buf.writeln('Summary (offline, extractive):');
    buf.writeln();
    var i = 0;
    for (final s in ranked.take(3)) {
      i++;
      buf.writeln('$i. ${s.trim()}');
    }
    buf.writeln();
    buf.writeln('Tip: for a more literary summary, an AI backend can be added later.');
    return buf.toString();
  }

  static List<String> _sentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _toneGuess(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('!')) return 'is emphatic and expressive';
    if (lower.contains('?')) return 'raises a question';
    if (lower.contains('because') || lower.contains('therefore') || lower.contains('thus')) {
      return 'explains a cause or reasoning';
    }
    if (lower.contains('imagine') || lower.contains('like') || lower.contains('as if')) {
      return 'uses imagery or comparison';
    }
    return 'is descriptive and informative';
  }

  static void showResultDialog(BuildContext context, String title, String content, {bool markdown = true}) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(content, style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
