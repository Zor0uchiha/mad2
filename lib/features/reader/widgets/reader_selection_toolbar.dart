import 'package:flutter/material.dart';
import '../highlights/highlight_model.dart';

enum ReaderSelectionAction {
  highlightYellow,
  highlightGreen,
  highlightBlue,
  highlightPink,
  highlightOrange,
  highlightPurple,
  underline,
  note,
  copy,
  translate,
  dictionary,
  explain,
  summarize,
  readAloud,
  share,
  saveQuote,
}

typedef SelectionActionHandler = void Function(ReaderSelectionAction action, String text);

class ReaderSelectionToolbar extends StatelessWidget {
  final String text;
  final SelectionActionHandler onAction;

  const ReaderSelectionToolbar({super.key, required this.text, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width - 24;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      color: scheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: 52,
          child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            const _Separator(),
            for (final c in HighlightColor.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _ColorDot(
                  color: Color(highlightColorValues[c] ?? 0xFFFFEB3B),
                  onTap: () => onAction(_colorAction(c), text),
                  tooltip: _colorName(c),
                ),
              ),
            const _Separator(),
            _ToolbarButton(
              icon: Icons.border_color_rounded,
              tooltip: "Highlight",
              onTap: () => onAction(ReaderSelectionAction.highlightYellow, text),
            ),
            _ToolbarButton(
              icon: Icons.format_underlined_rounded,
              tooltip: "Underline",
              onTap: () => onAction(ReaderSelectionAction.underline, text),
            ),
            _ToolbarButton(
              icon: Icons.note_add_rounded,
              tooltip: "Add note",
              onTap: () => onAction(ReaderSelectionAction.note, text),
            ),
            _ToolbarButton(
              icon: Icons.copy_rounded,
              tooltip: "Copy",
              onTap: () => onAction(ReaderSelectionAction.copy, text),
            ),
            _ToolbarButton(
              icon: Icons.translate_rounded,
              tooltip: "Translate",
              onTap: () => onAction(ReaderSelectionAction.translate, text),
            ),
            _ToolbarButton(
              icon: Icons.menu_book_rounded,
              tooltip: "Dictionary",
              onTap: () => onAction(ReaderSelectionAction.dictionary, text),
            ),
            _ToolbarButton(
              icon: Icons.auto_awesome_rounded,
              tooltip: "AI Explain",
              onTap: () => onAction(ReaderSelectionAction.explain, text),
            ),
            _ToolbarButton(
              icon: Icons.summarize_rounded,
              tooltip: "AI Summarize",
              onTap: () => onAction(ReaderSelectionAction.summarize, text),
            ),
            _ToolbarButton(
              icon: Icons.volume_up_rounded,
              tooltip: "Read aloud",
              onTap: () => onAction(ReaderSelectionAction.readAloud, text),
            ),
            _ToolbarButton(
              icon: Icons.share_rounded,
              tooltip: "Share",
              onTap: () => onAction(ReaderSelectionAction.share, text),
            ),
            _ToolbarButton(
              icon: Icons.format_quote_rounded,
              tooltip: "Save quote",
              onTap: () => onAction(ReaderSelectionAction.saveQuote, text),
            ),
          ],
        ),
        ),
      ),
    );
  }

  ReaderSelectionAction _colorAction(HighlightColor c) {
    switch (c) {
      case HighlightColor.yellow:
        return ReaderSelectionAction.highlightYellow;
      case HighlightColor.green:
        return ReaderSelectionAction.highlightGreen;
      case HighlightColor.blue:
        return ReaderSelectionAction.highlightBlue;
      case HighlightColor.pink:
        return ReaderSelectionAction.highlightPink;
      case HighlightColor.orange:
        return ReaderSelectionAction.highlightOrange;
      case HighlightColor.purple:
        return ReaderSelectionAction.highlightPurple;
    }
  }

  String _colorName(HighlightColor c) {
    switch (c) {
      case HighlightColor.yellow:
        return "Yellow";
      case HighlightColor.green:
        return "Green";
      case HighlightColor.blue:
        return "Blue";
      case HighlightColor.pink:
        return "Pink";
      case HighlightColor.orange:
        return "Orange";
      case HighlightColor.purple:
        return "Purple";
    }
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ColorDot({required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
          child: const Icon(Icons.format_quote_rounded, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
      color: Colors.black12,
    );
  }
}
