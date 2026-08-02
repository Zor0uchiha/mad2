import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../reader_preferences.dart';

class ReaderToolsDelegate {
  final VoidCallback onTableOfContents;
  final VoidCallback onBookmarks;
  final VoidCallback onAddNote;
  final VoidCallback onNotes;
  final VoidCallback onSearch;
  final VoidCallback onHighlights;
  final VoidCallback onQuoteEditor;
  final VoidCallback onGoToPage;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTypography;
  final VoidCallback onAiExplain;
  final VoidCallback onAiSummarize;
  final VoidCallback onDictionary;
  final VoidCallback onTranslate;
  final VoidCallback onReadAloud;

  const ReaderToolsDelegate({
    required this.onTableOfContents,
    required this.onBookmarks,
    required this.onAddNote,
    required this.onNotes,
    required this.onSearch,
    required this.onHighlights,
    required this.onQuoteEditor,
    required this.onGoToPage,
    required this.onToggleFullscreen,
    required this.onTypography,
    required this.onAiExplain,
    required this.onAiSummarize,
    required this.onDictionary,
    required this.onTranslate,
    required this.onReadAloud,
  });
}

class ReaderToolsSheet extends ConsumerWidget {
  final ReaderToolsDelegate delegate;

  const ReaderToolsSheet({super.key, required this.delegate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readerPreferencesProvider);
    final notifier = ref.read(readerPreferencesProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222B) : Colors.white;

    return Container(
      color: bg,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Tools",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _section(context, Icons.menu_book_rounded, "Reading", [
              _GridAction(Icons.list_rounded, "Contents", delegate.onTableOfContents),
              _GridAction(Icons.bookmarks_rounded, "Bookmarks", delegate.onBookmarks),
              _GridAction(Icons.numbers_rounded, "Go to page", delegate.onGoToPage),
              _GridAction(Icons.fullscreen_rounded, "Fullscreen", delegate.onToggleFullscreen),
            ]),
            _section(context, Icons.border_color_rounded, "Highlights & Notes", [
              _GridAction(Icons.highlight_rounded, "Highlights", delegate.onHighlights),
              _GridAction(Icons.format_quote_rounded, "Highlight & Quote", delegate.onQuoteEditor),
              _GridAction(Icons.note_add_rounded, "Add note", delegate.onAddNote),
              _GridAction(Icons.notes_rounded, "My notes", delegate.onNotes),
            ]),
            _section(context, Icons.search_rounded, "Search", [
              _GridAction(Icons.search_rounded, "Search in book", delegate.onSearch),
            ]),
            _section(context, Icons.palette_rounded, "Themes", [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: readerThemeSpecs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final spec = readerThemeSpecs[i];
                          final selected = prefs.theme == spec.id;
                          return GestureDetector(
                            onTap: () {
                              notifier.update(prefs.copyWith(theme: spec.id));
                            },
                            child: Container(
                              width: 68,
                              decoration: BoxDecoration(
                                color: spec.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? AppColors.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 18, color: spec.text),
                                  const SizedBox(height: 4),
                                  Text(
                                    spec.name,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: spec.text),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.brightness_6_rounded, size: 18),
                        Expanded(
                          child: Slider(
                            value: prefs.brightness,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (v) => notifier.update(prefs.copyWith(brightness: v)),
                          ),
                        ),
                        const Icon(Icons.brightness_high_rounded, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            _section(context, Icons.settings_rounded, "Reading Mode", [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ToggleRow(
                      label: "Vertical scroll",
                      subtitle: "Continuous scroll instead of pages",
                      value: prefs.verticalScroll,
                      onChanged: (v) => notifier.update(prefs.copyWith(verticalScroll: v)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Page turn animation",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final mode in PageTurnMode.values)
                          ChoiceChip(
                            label: Text(_turnLabel(mode)),
                            selected: prefs.pageTurnMode == mode,
                            onSelected: (_) => notifier.update(prefs.copyWith(pageTurnMode: mode)),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            _section(context, Icons.auto_awesome_rounded, "AI Tools", [
              _GridAction(Icons.auto_awesome_rounded, "Explain", delegate.onAiExplain),
              _GridAction(Icons.summarize_rounded, "Summarize", delegate.onAiSummarize),
              _GridAction(Icons.menu_book_rounded, "Dictionary", delegate.onDictionary),
              _GridAction(Icons.translate_rounded, "Translate", delegate.onTranslate),
              _GridAction(Icons.volume_up_rounded, "Read aloud", delegate.onReadAloud),
            ]),
            _section(context, Icons.tune_rounded, "Settings", [
              _GridAction(Icons.text_fields_rounded, "Typography", delegate.onTypography),
              _GridAction(Icons.contrast_rounded, "High contrast", () {
                notifier.update(prefs.copyWith(highContrast: !prefs.highContrast));
              }),
              _GridAction(Icons.handyman_rounded, "One-hand mode", () {
                notifier.update(prefs.copyWith(oneHandMode: !prefs.oneHandMode));
              }),
              _GridAction(Icons.fork_left_rounded, "Left-handed", () {
                notifier.update(prefs.copyWith(leftHanded: !prefs.leftHanded));
              }),
              _GridAction(Icons.battery_charging_full_rounded, "Keep screen awake", () {
                notifier.update(prefs.copyWith(keepScreenAwake: !prefs.keepScreenAwake));
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, IconData icon, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.95,
            children: children,
          ),
        ],
      ),
    );
  }

  String _turnLabel(PageTurnMode mode) {
    switch (mode) {
      case PageTurnMode.slide:
        return "Slide";
      case PageTurnMode.fade:
        return "Fade";
      case PageTurnMode.curl:
        return "Curl";
      case PageTurnMode.kindle:
        return "Kindle";
      case PageTurnMode.none:
        return "None";
    }
  }
}

class _GridAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GridAction(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.accent),
      ],
    );
  }
}
