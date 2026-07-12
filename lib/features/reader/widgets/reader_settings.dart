import "package:flutter/material.dart";

enum ReaderTheme { light, sepia, dark }

class ReaderSettingsSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Reading Settings",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Text("Font Size", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.text_fields, size: 18),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 20,
                    onChanged: onFontSizeChanged,
                  ),
                ),
                const Icon(Icons.text_fields, size: 26),
              ],
            ),
            const SizedBox(height: 20),
            Text("Brightness", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.brightness_low, size: 18),
                Expanded(
                  child: Slider(
                    value: brightness,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    onChanged: onBrightnessChanged,
                  ),
                ),
                const Icon(Icons.brightness_high, size: 22),
              ],
            ),
            const SizedBox(height: 20),
            Text("Theme", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                _ThemeOption(
                  icon: Icons.light_mode_rounded,
                  label: "Light",
                  isSelected: readerTheme == ReaderTheme.light,
                  onTap: () => onThemeChanged(ReaderTheme.light),
                ),
                const SizedBox(width: 12),
                _ThemeOption(
                  icon: Icons.wb_sunny_rounded,
                  label: "Sepia",
                  isSelected: readerTheme == ReaderTheme.sepia,
                  onTap: () => onThemeChanged(ReaderTheme.sepia),
                ),
                const SizedBox(width: 12),
                _ThemeOption(
                  icon: Icons.dark_mode_rounded,
                  label: "Dark",
                  isSelected: readerTheme == ReaderTheme.dark,
                  onTap: () => onThemeChanged(ReaderTheme.dark),
                ),
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

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
