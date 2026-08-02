import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';

enum QuoteCardTemplate { minimal, classic, dark, glass, gradient, kindle, story, twitter, pinterest }

enum QuoteFontChoice { serif, sans, script }

class QuoteCardScreen extends ConsumerStatefulWidget {
  final String quote;
  final String bookTitle;
  final String bookAuthor;
  final String? bookId;
  final int pageIndex;
  final String chapterName;

  const QuoteCardScreen({
    super.key,
    required this.quote,
    required this.bookTitle,
    required this.bookAuthor,
    this.bookId,
    this.pageIndex = 0,
    this.chapterName = "",
  });

  @override
  ConsumerState<QuoteCardScreen> createState() => _QuoteCardScreenState();
}

class _QuoteCardScreenState extends ConsumerState<QuoteCardScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  QuoteCardTemplate _template = QuoteCardTemplate.gradient;
  QuoteFontChoice _font = QuoteFontChoice.serif;
  Color _accent = AppColors.accent;
  Color _bg = const Color(0xFF0F1115);
  Color _textColor = Colors.white;
  bool _showUsername = true;
  bool _showDate = true;
  final TextEditingController _usernameController = TextEditingController();
  Uint8List? _coverBytes;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = "Your Name";
    _loadCover();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadCover() async {
    final bookId = widget.bookId;
    if (bookId == null || bookId.isEmpty) return;
    try {
      final book = await ref.read(booksProvider).getBook(bookId);
      final path = book?.coverPath;
      if (path == null || path.isEmpty) return;
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _coverBytes = bytes);
      }
    } catch (_) {}
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png')],
        text: '"${widget.quote}" — ${widget.bookTitle}',
        fileNameOverrides: ['libora_quote.png'],
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not generate the quote card.")),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayQuote = widget.quote.trim().isEmpty
        ? "Reading is a conversation. All books talk. But a good book listens as well."
        : widget.quote.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF12141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12141A),
        title: const Text("Quote Card"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Reset",
            onPressed: () {
              setState(() {
                _template = QuoteCardTemplate.gradient;
                _font = QuoteFontChoice.serif;
                _accent = AppColors.accent;
                _showUsername = true;
                _showDate = true;
              });
            },
          ),
          FilledButton.icon(
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded, size: 18),
            label: const Text("Share"),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: _buildCard(displayQuote),
                ),
              ),
            ),
          ),
          _buildTemplateSelector(),
          _buildCustomizePanel(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    const templates = <(QuoteCardTemplate, IconData, String)>[
      (QuoteCardTemplate.minimal, Icons.article_rounded, "Minimal"),
      (QuoteCardTemplate.classic, Icons.park_rounded, "Classic"),
      (QuoteCardTemplate.dark, Icons.dark_mode_rounded, "Dark"),
      (QuoteCardTemplate.glass, Icons.blur_on_rounded, "Glass"),
      (QuoteCardTemplate.gradient, Icons.gradient_rounded, "Gradient"),
      (QuoteCardTemplate.kindle, Icons.wb_incandescent_rounded, "Kindle"),
      (QuoteCardTemplate.story, Icons.crop_portrait_rounded, "Story"),
      (QuoteCardTemplate.twitter, Icons.tag_rounded, "Twitter"),
      (QuoteCardTemplate.pinterest, Icons.dashboard_rounded, "Pinterest"),
    ];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (t, icon, label) = templates[i];
          final selected = _template == t;
          return InkWell(
            onTap: () => setState(() => _template = t),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent.withOpacity(0.18) : Colors.white10,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: selected ? AppColors.accent : Colors.white70),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? AppColors.accent : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomizePanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _label("Accent"),
              const SizedBox(width: 12),
              for (final c in [AppColors.accent, const Color(0xFF1A73E8), const Color(0xFF34A853), const Color(0xFFFFB300), const Color(0xFF9C27B0)])
                GestureDetector(
                  onTap: () => setState(() => _accent = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _accent == c ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                  ),
                ),
              const Spacer(),
              _label("Font"),
              const SizedBox(width: 8),
              _fontChip("Serif", QuoteFontChoice.serif),
              const SizedBox(width: 4),
              _fontChip("Sans", QuoteFontChoice.sans),
              const SizedBox(width: 4),
              _fontChip("Script", QuoteFontChoice.script),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _label("Background"),
              const SizedBox(width: 12),
              for (final c in [
                const Color(0xFF0F1115),
                const Color(0xFFFFFFFF),
                const Color(0xFFF5E6C8),
                const Color(0xFF7C4DFF),
                const Color(0xFF1A73E8),
              ])
                GestureDetector(
                  onTap: () => setState(() => _bg = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _bg == c ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                  ),
                ),
              const Spacer(),
              const Icon(Icons.emoji_people_rounded, size: 16, color: Colors.white70),
              Switch(
                value: _showUsername,
                onChanged: (v) => setState(() => _showUsername = v),
                activeColor: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
              Switch(
                value: _showDate,
                onChanged: (v) => setState(() => _showDate = v),
                activeColor: AppColors.accent,
              ),
            ],
          ),
          if (_showUsername)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "User name",
                  labelStyle: const TextStyle(color: Colors.white54),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _fontChip(String label, QuoteFontChoice choice) {
    final selected = _font == choice;
    return GestureDetector(
      onTap: () => setState(() => _font = choice),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String quote) {
    final isDark = _isDark(_template, _bg);
    final cover = _coverBytes != null
        ? Image.memory(_coverBytes!, fit: BoxFit.cover, gaplessPlayback: true)
        : Container(color: _accent.withOpacity(0.25), child: const Center(child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 32)));

    final font = _fontStyle();
    final metaColor = isDark ? Colors.white70 : Colors.black54;
    final accent = _accent;

    Widget buildQuote(String? fontFamily) {
      return Text(
        quote,
        textAlign: TextAlign.center,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: (fontFamily == null ? font : font.copyWith(fontFamily: fontFamily)).copyWith(
          fontSize: _template == QuoteCardTemplate.story ? 26 : 22,
          height: 1.35,
          color: _textColorFor(isDark),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Widget footer({String? divider}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (divider != null)
            Container(width: 36, height: 3, margin: const EdgeInsets.only(bottom: 10), color: accent),
          Text(widget.bookTitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 2),
          Text(widget.bookAuthor, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: metaColor)),
        ],
      );
    }

    switch (_template) {
      case QuoteCardTemplate.minimal:
        return _cardBox(
          aspect: 0.8,
          background: _bg,
          borderRadius: 18,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.format_quote_rounded, size: 40, color: accent),
                const SizedBox(height: 16),
                buildQuote(null),
                const SizedBox(height: 20),
                footer(divider: "line"),
              ],
            ),
          ),
        );
      case QuoteCardTemplate.classic:
        return _cardBox(
          aspect: 0.78,
          background: const Color(0xFFFDF6E3),
          borderRadius: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFB48B4A), width: 1.5),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.bookTitle.toUpperCase(),
                  style: TextStyle(fontSize: 11, letterSpacing: 3, color: const Color(0xFF7A5A32)),
                ),
                const SizedBox(height: 6),
                Container(width: 60, height: 1, color: const Color(0xFFB48B4A)),
                const SizedBox(height: 18),
                Text(quote, textAlign: TextAlign.center, maxLines: 6, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(fontSize: 20, height: 1.4, color: const Color(0xFF3E2C1C))),
                const SizedBox(height: 18),
                Container(width: 60, height: 1, color: const Color(0xFFB48B4A)),
                const SizedBox(height: 10),
                Text("— ${widget.bookAuthor}", style: TextStyle(fontSize: 12, color: const Color(0xFF7A5A32), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        );
      case QuoteCardTemplate.dark:
        return _cardBox(
          aspect: 0.8,
          background: const Color(0xFF111418),
          borderRadius: 18,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(width: 160, height: 160, decoration: BoxDecoration(color: accent.withOpacity(0.25), shape: BoxShape.circle)),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildQuote(_font == QuoteFontChoice.serif ? 'Lora' : null),
                    const SizedBox(height: 22),
                    footer(divider: "line"),
                  ],
                ),
              ),
            ],
          ),
        );
      case QuoteCardTemplate.glass:
        return _cardBox(
          aspect: 0.8,
          background: _bg,
          borderRadius: 22,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withOpacity(0.55), const Color(0xFF2E3A59).withOpacity(0.65)],
              ),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildQuote(_font == QuoteFontChoice.serif ? 'Lora' : null),
                const SizedBox(height: 20),
                footer(),
              ],
            ),
          ),
        );
      case QuoteCardTemplate.gradient:
        return _cardBox(
          aspect: 0.8,
          background: _bg,
          borderRadius: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withOpacity(0.55)],
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildQuote(_font == QuoteFontChoice.serif ? 'Lora' : null),
                const SizedBox(height: 20),
                footer(divider: "line"),
              ],
            ),
          ),
        );
      case QuoteCardTemplate.kindle:
        return _cardBox(
          aspect: 0.8,
          background: const Color(0xFFF3EBDD),
          borderRadius: 14,
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_stories_rounded, size: 30, color: Color(0xFF8A6D3B)),
                const SizedBox(height: 14),
                Text(quote, textAlign: TextAlign.center, maxLines: 6, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lora(fontSize: 20, height: 1.4, color: const Color(0xFF2B2416))),
                const SizedBox(height: 16),
                Text("— ${widget.bookAuthor}", style: TextStyle(fontSize: 12, color: const Color(0xFF8A6D3B), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        );
      case QuoteCardTemplate.story:
        return _cardBox(
          aspect: 0.56,
          background: _bg,
          borderRadius: 22,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverBytes != null)
                Positioned.fill(child: Image.memory(_coverBytes!, fit: BoxFit.cover)),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.black.withOpacity(0.82)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Container(width: 44, height: 4, color: accent),
                    const SizedBox(height: 14),
                    Text(quote, maxLines: 6, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lora(fontSize: 24, height: 1.3, color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    Text("— ${widget.bookTitle} · ${widget.bookAuthor}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        );
      case QuoteCardTemplate.twitter:
        return _cardBox(
          aspect: 1.0,
          background: _bg,
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(width: 40, height: 40, child: cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          Text(widget.bookAuthor, style: TextStyle(fontSize: 12, color: metaColor)),
                        ],
                      ),
                    ),
                    Icon(Icons.tag_rounded, size: 22, color: accent),
                  ],
                ),
                const Spacer(),
                buildQuote(_font == QuoteFontChoice.serif ? 'Lora' : null),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_showDate)
                      Text(_dateLabel(), style: TextStyle(fontSize: 12, color: metaColor)),
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, size: 14, color: accent),
                        const SizedBox(width: 4),
                        Text("LIBORA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: accent)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case QuoteCardTemplate.pinterest:
        return _cardBox(
          aspect: 0.62,
          background: _bg,
          borderRadius: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover,
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote, maxLines: 5, overflow: TextOverflow.ellipsis,
                        style: (_font == QuoteFontChoice.serif ? GoogleFonts.lora() : font).copyWith(fontSize: 17, height: 1.35, color: _textColorFor(isDark), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text("${widget.bookTitle} · ${widget.bookAuthor}", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: metaColor)),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  TextStyle _fontStyle() {
    switch (_font) {
      case QuoteFontChoice.serif:
        return GoogleFonts.lora();
      case QuoteFontChoice.sans:
        return GoogleFonts.poppins();
      case QuoteFontChoice.script:
        return GoogleFonts.playfairDisplay();
    }
  }

  bool _isDark(QuoteCardTemplate template, Color bg) {
    if (template == QuoteCardTemplate.gradient ||
        template == QuoteCardTemplate.glass ||
        template == QuoteCardTemplate.dark ||
        template == QuoteCardTemplate.story ||
        template == QuoteCardTemplate.pinterest ||
        template == QuoteCardTemplate.twitter) {
      return true;
    }
    return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
  }

  Color _textColorFor(bool isDark) {
    return isDark ? Colors.white : const Color(0xFF222222);
  }

  String _dateLabel() {
    final now = DateTime.now();
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${now.day} ${months[now.month - 1]} ${now.year}";
  }

  Widget _cardBox({required double aspect, required Color background, required double borderRadius, required Widget child}) {
    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
