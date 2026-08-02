import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../reader_preferences.dart';

class ReaderStyleSheet extends ConsumerWidget {
  const ReaderStyleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readerPreferencesProvider);
    final notifier = ref.read(readerPreferencesProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222B) : Colors.white;

    return Container(
      color: bg,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Typography",
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _label(context, "Font Family"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in ReaderFontId.values)
                  ChoiceChip(
                    label: Text(_fontName(f), style: TextStyle(fontFamily: _fontPreview(f))),
                    selected: prefs.fontFamily == f,
                    onSelected: (_) => notifier.update(prefs.copyWith(fontFamily: f)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _label(context, "Font Size"),
            _sliderRow(context, prefs.fontSize, 12, 32, 40,
                (v) => notifier.update(prefs.copyWith(fontSize: v)), "${prefs.fontSize.round()}"),
            const SizedBox(height: 12),
            _label(context, "Font Weight"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final w in ReaderWeight.values)
                  ChoiceChip(
                    label: Text(_weightName(w)),
                    selected: prefs.fontWeight == w,
                    onSelected: (_) => notifier.update(prefs.copyWith(fontWeight: w)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _label(context, "Line Height"),
            _sliderRow(context, prefs.lineHeight, 1.2, 2.2, 50,
                (v) => notifier.update(prefs.copyWith(lineHeight: v)), prefs.lineHeight.toStringAsFixed(1)),
            const SizedBox(height: 12),
            _label(context, "Paragraph Spacing"),
            _sliderRow(context, prefs.paragraphSpacing, 0, 28, 28,
                (v) => notifier.update(prefs.copyWith(paragraphSpacing: v)), prefs.paragraphSpacing.round().toString()),
            const SizedBox(height: 12),
            _label(context, "Margins"),
            _sliderRow(context, prefs.margin, 8, 44, 36,
                (v) => notifier.update(prefs.copyWith(margin: v)), prefs.margin.round().toString()),
            const SizedBox(height: 12),
            _label(context, "Letter Spacing"),
            _sliderRow(context, prefs.letterSpacing, 0, 1.0, 20,
                (v) => notifier.update(prefs.copyWith(letterSpacing: v)), prefs.letterSpacing.toStringAsFixed(2)),
            const SizedBox(height: 18),
            _label(context, "Text Alignment"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("Justify"),
                  selected: prefs.alignment == TextAlign.justify,
                  onSelected: (_) => notifier.update(prefs.copyWith(alignment: TextAlign.justify)),
                ),
                ChoiceChip(
                  label: const Text("Left"),
                  selected: prefs.alignment == TextAlign.left,
                  onSelected: (_) => notifier.update(prefs.copyWith(alignment: TextAlign.left)),
                ),
                ChoiceChip(
                  label: const Text("Center"),
                  selected: prefs.alignment == TextAlign.center,
                  onSelected: (_) => notifier.update(prefs.copyWith(alignment: TextAlign.center)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.accent,
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
    String display,
  ) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _fontName(ReaderFontId f) {
    switch (f) {
      case ReaderFontId.system:
        return "Default";
      case ReaderFontId.serif:
        return "Serif";
      case ReaderFontId.sans:
        return "Sans";
      case ReaderFontId.monospace:
        return "Mono";
      case ReaderFontId.dyslexic:
        return "Dyslexic";
    }
  }

  String? _fontPreview(ReaderFontId f) {
    switch (f) {
      case ReaderFontId.serif:
        return 'serif';
      case ReaderFontId.sans:
        return 'sans-serif';
      case ReaderFontId.monospace:
        return 'monospace';
      default:
        return null;
    }
  }

  String _weightName(ReaderWeight w) {
    switch (w) {
      case ReaderWeight.regular:
        return "Regular";
      case ReaderWeight.medium:
        return "Medium";
      case ReaderWeight.semibold:
        return "Semi-bold";
      case ReaderWeight.bold:
        return "Bold";
    }
  }
}
