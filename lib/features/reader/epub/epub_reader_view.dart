import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../highlights/highlight_model.dart';
import '../reader_preferences.dart';
import '../widgets/reader_selection_toolbar.dart';
import 'epub_parser.dart';

class EpubReaderView extends StatefulWidget {
  final EpubChapterData chapter;
  final ReaderPreferences prefs;
  final List<HighlightModel> highlights;
  final bool paged;
  final double initialScrollFraction;
  final int initialPage;
  final ValueChanged<double>? onScrollFraction;
  final ValueChanged<int>? onPageChanged;
  final SelectionActionHandler? onSelection;

  const EpubReaderView({
    super.key,
    required this.chapter,
    required this.prefs,
    required this.highlights,
    required this.paged,
    this.initialScrollFraction = 0,
    this.initialPage = 0,
    this.onScrollFraction,
    this.onPageChanged,
    this.onSelection,
  });

  @override
  State<EpubReaderView> createState() => EpubReaderViewState();
}

class EpubReaderViewState extends State<EpubReaderView> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final List<GlobalKey> _blockKeys = [];
  List<List<int>> _pages = [];
  bool _measured = false;
  bool _packScheduled = false;
  int _packCount = 0;
  int _page = 0;
  int _anchorBlock = 0;
  bool _initialJumpDone = false;
  String _selectionText = '';

  int get currentPage => _page;
  int get pageCount => _pages.isEmpty ? 1 : _pages.length;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter != widget.chapter) {
      _resetForLayout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } else if (!_sameStyle(oldWidget.prefs, widget.prefs)) {
      _resetForLayout();
    }
  }

  bool _sameStyle(ReaderPreferences a, ReaderPreferences b) {
    return a.fontSize == b.fontSize &&
        a.fontFamily == b.fontFamily &&
        a.fontWeight == b.fontWeight &&
        a.lineHeight == b.lineHeight &&
        a.paragraphSpacing == b.paragraphSpacing &&
        a.margin == b.margin &&
        a.letterSpacing == b.letterSpacing &&
        a.alignment == b.alignment &&
        a.highContrast == b.highContrast;
  }

  void _resetForLayout() {
    _pages = [];
    _measured = false;
    _packScheduled = false;
    _packCount = 0;
    _anchorBlock = 0;
    _initialJumpDone = false;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    widget.onScrollFraction?.call(_scrollController.offset / max);
  }

  void nextPage() {
    if (widget.paged) {
      if (_page < pageCount - 1) _goToPage(_page + 1);
    }
  }

  void previousPage() {
    if (widget.paged) {
      if (_page > 0) _goToPage(_page - 1);
    }
  }

  void goToPage(int page) {
    if (!widget.paged) return;
    _goToPage(page.clamp(0, pageCount - 1).toInt());
  }

  void _goToPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    widget.onPageChanged?.call(page);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!widget.paged) {
          return _buildScrollView();
        }
        if (!_measured || _pages.isEmpty) {
          if (widget.chapter.blocks.isEmpty) {
            return const Center(child: Text("This chapter is empty."));
          }
          if (!_packScheduled) {
            _packScheduled = true;
            _blockKeys
              ..clear()
              ..addAll(List.generate(widget.chapter.blocks.length, (_) => GlobalKey()));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pack(constraints.maxWidth, constraints.maxHeight);
            });
          }
          return _buildMeasureColumn(constraints.maxWidth);
        }
        return _buildPageView(constraints.maxWidth);
      },
    );
  }

  Widget _buildScrollView() {
    if (!_initialJumpDone) {
      _initialJumpDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && widget.initialScrollFraction > 0) {
          final max = _scrollController.position.maxScrollExtent;
          if (max > 0) {
            _scrollController.jumpTo((widget.initialScrollFraction * max).clamp(0.0, max).toDouble());
          }
        }
      });
    }
    return SelectionArea(
      contextMenuBuilder: _selectionMenu,
      onSelectionChanged: _onSelectionChanged,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          widget.prefs.margin,
          widget.prefs.margin * 0.6,
          widget.prefs.margin,
          widget.prefs.margin * 1.4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final b in widget.chapter.blocks)
              Padding(
                padding: EdgeInsets.only(bottom: widget.prefs.paragraphSpacing),
                child: _buildBlock(b),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasureColumn(double width) {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.chapter.blocks.length; i++)
                Padding(
                  key: _blockKeys[i],
                  padding: EdgeInsets.only(bottom: widget.prefs.paragraphSpacing),
                  child: _buildBlock(widget.chapter.blocks[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pack(double width, double height) {
    _packScheduled = false;
    _packCount++;
    final heights = _blockKeys
        .map((k) => k.currentContext?.size?.height ?? 0.0)
        .toList();
    final pages = <List<int>>[];
    var current = <int>[];
    var used = 0.0;
    for (var i = 0; i < heights.length; i++) {
      final h = heights[i];
      if (h <= 0) continue;
      if (current.isNotEmpty && used + h > height) {
        pages.add(List.of(current));
        current = [];
        used = 0;
      }
      current.add(i);
      used += h;
    }
    if (current.isNotEmpty) pages.add(current);

    if (pages.isEmpty && heights.isNotEmpty) {
      if (_packCount < 5 && heights.every((h) => h <= 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pack(width, height);
        });
        return;
      }
      pages.add([for (var i = 0; i < heights.length; i++) i]);
    }

    var newPage = 0;
    if (_anchorBlock < widget.chapter.blocks.length) {
      for (var p = 0; p < pages.length; p++) {
        if (pages[p].contains(_anchorBlock)) {
          newPage = p;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _pages = pages;
      _measured = true;
      _page = newPage;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(newPage);
    }
    widget.onPageChanged?.call(newPage);
  }

  Widget _buildPageView(double width) {
    if (_pages.isEmpty) {
      return const Center(child: Text("This chapter is empty."));
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: pageCount,
      onPageChanged: (page) {
        if (page == _page) return;
        setState(() {
          _page = page;
          _anchorBlock = _pages[page].isNotEmpty ? _pages[page].first : 0;
        });
        widget.onPageChanged?.call(page);
      },
      itemBuilder: (context, page) {
        if (page >= _pages.length) return const SizedBox.shrink();
        final blocks = _pages[page];
        return SelectionArea(
          contextMenuBuilder: _selectionMenu,
          onSelectionChanged: _onSelectionChanged,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              widget.prefs.margin,
              widget.prefs.margin * 0.6,
              widget.prefs.margin,
              widget.prefs.margin,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final idx in blocks)
                  Padding(
                    padding: EdgeInsets.only(bottom: widget.prefs.paragraphSpacing),
                    child: _buildBlock(widget.chapter.blocks[idx]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _selectionMenu(BuildContext context, SelectableRegionState state) {
    final text = _selectionText.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return ReaderSelectionToolbar(
      text: text,
      onAction: (action, t) {
        state.hideToolbar();
        widget.onSelection?.call(action, t);
      },
    );
  }

  void _onSelectionChanged(SelectedContent? content) {
    _selectionText = content?.plainText ?? '';
  }

  Widget _buildBlock(EpubBlock block) {
    final prefs = widget.prefs;
    switch (block.type) {
      case EpubBlockType.heading:
        return SelectableText.rich(
          _buildSpans(block, prefs.headingStyle(block.level)),
          textAlign: prefs.alignment,
        );
      case EpubBlockType.paragraph:
        return SelectableText.rich(
          _buildSpans(block, prefs.bodyStyle()),
          textAlign: prefs.alignment,
        );
      case EpubBlockType.blockquote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
            color: _quoteBg(),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText.rich(
            _buildSpans(block, prefs.bodyStyle().copyWith(fontStyle: FontStyle.italic)),
            textAlign: prefs.alignment,
          ),
        );
      case EpubBlockType.listItem:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Text('•', style: prefs.bodyStyle().copyWith(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: SelectableText.rich(_buildSpans(block, prefs.bodyStyle()), textAlign: prefs.alignment),
            ),
          ],
        );
      case EpubBlockType.image:
        final bytes = widget.chapter.images[block.imageKey];
        if (bytes == null) return const SizedBox.shrink();
        return Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      case EpubBlockType.table:
        return _buildTable(block);
      case EpubBlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: widget.prefs.themeSpec.hint),
        );
      case EpubBlockType.preformatted:
        return SelectableText.rich(
          _buildSpans(block, prefs.bodyStyle().copyWith(fontFamily: 'monospace')),
          textAlign: TextAlign.left,
        );
    }
  }

  Widget _buildTable(EpubBlock block) {
    if (block.tableRows.isEmpty) return const SizedBox.shrink();
    final textStyle = widget.prefs.bodyStyle().copyWith(fontSize: widget.prefs.effectiveFontSize * 0.85);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: widget.prefs.themeSpec.hint, width: 0.5),
        children: [
          for (final row in block.tableRows)
            TableRow(
              children: [
                for (final cell in row)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: SelectableText(cell, style: textStyle),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _quoteBg() {
    final themeSpec = widget.prefs.themeSpec;
    final isDark = ThemeData.estimateBrightnessForColor(themeSpec.background) == Brightness.dark;
    return isDark ? themeSpec.background.withOpacity(0.6) : themeSpec.background.withOpacity(0.5);
  }

  TextSpan _buildSpans(EpubBlock block, TextStyle base) {
    final children = <InlineSpan>[];
    for (final inline in block.inlines) {
      var style = base;
      if (inline.bold) style = style.copyWith(fontWeight: FontWeight.bold);
      if (inline.italic) style = style.copyWith(fontStyle: FontStyle.italic);
      if (inline.footnote) {
        style = style.copyWith(
          fontSize: base.fontSize! * 0.7,
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
        );
      }
      TapGestureRecognizer? recognizer;
      if (inline.href != null) {
        final isInternal = inline.href!.startsWith('#');
        style = style.copyWith(
          color: AppColors.accent,
          decoration: isInternal ? TextDecoration.none : TextDecoration.underline,
        );
        recognizer = TapGestureRecognizer()
          ..onTap = () => _openLink(inline.href!, inline.footnote);
      }
      children.addAll(_inlineWithHighlights(inline.text, style, recognizer));
    }
    return TextSpan(style: base, children: children);
  }

  List<InlineSpan> _inlineWithHighlights(
    String text,
    TextStyle style,
    TapGestureRecognizer? recognizer,
  ) {
    final highlights = widget.highlights.where((h) => h.text.trim().isNotEmpty).toList();
    final matches = <({int start, int end, HighlightModel highlight})>[];
    final lower = text.toLowerCase();
    for (final h in highlights) {
      final hl = h.text.toLowerCase();
      if (hl.isEmpty) continue;
      var idx = lower.indexOf(hl);
      while (idx != -1) {
        matches.add((start: idx, end: idx + hl.length, highlight: h));
        idx = lower.indexOf(hl, idx + 1);
      }
    }

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: style, recognizer: recognizer)];
    }

    matches.sort((a, b) => a.start - b.start);
    final merged = <({int start, int end, HighlightModel highlight})>[];
    for (final m in matches) {
      if (merged.isEmpty || m.start >= merged.last.end) {
        merged.add(m);
      } else if (m.end > merged.last.end) {
        final last = merged.last;
        merged[merged.length - 1] = (start: last.start, end: m.end, highlight: m.highlight);
      }
    }

    final result = <InlineSpan>[];
    var pos = 0;
    for (final m in merged) {
      if (m.start > pos) {
        result.add(TextSpan(text: text.substring(pos, m.start), style: style, recognizer: recognizer));
      }
      final color = Color(highlightColorValues[m.highlight.color] ?? 0xFFFFEB3B);
      result.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: style.copyWith(
            backgroundColor: color.withOpacity(0.45),
            decoration: m.highlight.underlined ? TextDecoration.underline : null,
          ),
          recognizer: recognizer,
        ),
      );
      pos = m.end;
    }
    if (pos < text.length) {
      result.add(TextSpan(text: text.substring(pos), style: style, recognizer: recognizer));
    }
    return result;
  }

  void _openLink(String href, bool isFootnote) {
    if (isFootnote && href.startsWith('#')) {
      final id = href.substring(1);
      final el = widget.chapter.document.getElementById(id);
      final text = el?.text.trim();
      if (text != null && text.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Footnote"),
            content: SingleChildScrollView(
              child: SelectableText(text),
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
      return;
    }
    if (href.startsWith('http://') || href.startsWith('https://')) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
    }
  }
}
