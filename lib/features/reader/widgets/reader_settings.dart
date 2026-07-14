import "package:flutter/material.dart";

enum ReaderTheme { light, sepia, dark }

class ReaderSettingsSheet extends StatefulWidget {
  final double fontSize;
  final double brightness;
  final ReaderTheme readerTheme;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<ReaderTheme> onThemeChanged;

  const ReaderSettingsSheet({
    required this.fontSize,
    required this.brightness,
    required this.readerTheme,
    required this.onFontSizeChanged,
    required this.onBrightnessChanged,
    required this.onThemeChanged,
    super.key,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late double _fontSize;
  late double _brightness;
  late ReaderTheme _readerTheme;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _brightness = widget.brightness;
    _readerTheme = widget.readerTheme;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E222B) : Colors.white;

    return Container(
      color: bgColor,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text("Reading Settings", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text("Theme", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _ThemeOption(
                  icon: Icons.light_mode_rounded, label: "Light",
                  isSelected: _readerTheme == ReaderTheme.light,
                  onTap: () => setState(() {
                    _readerTheme = ReaderTheme.light;
                    widget.onThemeChanged(ReaderTheme.light);
                  }),
                ),
                const SizedBox(width: 12),
                _ThemeOption(
                  icon: Icons.wb_sunny_rounded, label: "Sepia",
                  isSelected: _readerTheme == ReaderTheme.sepia,
                  onTap: () => setState(() {
                    _readerTheme = ReaderTheme.sepia;
                    widget.onThemeChanged(ReaderTheme.sepia);
                  }),
                ),
                const SizedBox(width: 12),
                _ThemeOption(
                  icon: Icons.dark_mode_rounded, label: "Dark",
                  isSelected: _readerTheme == ReaderTheme.dark,
                  onTap: () => setState(() {
                    _readerTheme = ReaderTheme.dark;
                    widget.onThemeChanged(ReaderTheme.dark);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("Font Size", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.text_fields, size: 18),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 12.0, max: 32.0, divisions: 20,
                    label: "${_fontSize.toInt()}pt",
                    onChanged: (v) => setState(() {
                      _fontSize = v;
                      widget.onFontSizeChanged(v);
                    }),
                  ),
                ),
                const Icon(Icons.text_fields, size: 26),
              ],
            ),
            const SizedBox(height: 16),
            Text("Brightness", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.brightness_low, size: 18),
                Expanded(
                  child: Slider(
                    value: _brightness,
                    min: 0.1, max: 1.0, divisions: 9,
                    label: "${(_brightness * 100).toInt()}%",
                    onChanged: (v) => setState(() {
                      _brightness = v;
                      widget.onBrightnessChanged(v);
                    }),
                  ),
                ),
                const Icon(Icons.brightness_high, size: 22),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = const Color(0xFFE53935);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.15) : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: accent, width: 2) : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? accent : colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? accent : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
