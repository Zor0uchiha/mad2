import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

enum ReaderThemeId { light, sepia, dark, night, green, blue }

enum PageTurnMode { slide, fade, curl, kindle, none }

enum ReaderFontId { system, serif, sans, monospace, dyslexic }

enum ReaderWeight { regular, medium, semibold, bold }

class ReaderThemeSpec {
  final ReaderThemeId id;
  final String name;
  final Color background;
  final Color text;
  final Color hint;
  final Color overlay;

  const ReaderThemeSpec({
    required this.id,
    required this.name,
    required this.background,
    required this.text,
    required this.hint,
    this.overlay = Colors.transparent,
  });
}

const List<ReaderThemeSpec> readerThemeSpecs = [
  ReaderThemeSpec(
    id: ReaderThemeId.light,
    name: "Light",
    background: Color(0xFFFBF6EC),
    text: Color(0xFF2B2A28),
    hint: Color(0x66000000),
  ),
  ReaderThemeSpec(
    id: ReaderThemeId.sepia,
    name: "Sepia",
    background: Color(0xFFF5E6C8),
    text: Color(0xFF5B4636),
    hint: Color(0x665B4636),
  ),
  ReaderThemeSpec(
    id: ReaderThemeId.dark,
    name: "Dark",
    background: Color(0xFF1A1A2E),
    text: Color(0xFFCFD0D8),
    hint: Color(0x66FFFFFF),
  ),
  ReaderThemeSpec(
    id: ReaderThemeId.night,
    name: "Night",
    background: Color(0xFF000000),
    text: Color(0xFFE6E6E6),
    hint: Color(0x59FFFFFF),
  ),
  ReaderThemeSpec(
    id: ReaderThemeId.green,
    name: "Green",
    background: Color(0xFFE9F1E7),
    text: Color(0xFF24372A),
    hint: Color(0x6624372A),
  ),
  ReaderThemeSpec(
    id: ReaderThemeId.blue,
    name: "Blue",
    background: Color(0xFFE6F0FA),
    text: Color(0xFF1E3042),
    hint: Color(0x661E3042),
  ),
];

class ReaderPreferences {
  final ReaderThemeId theme;
  final double fontSize;
  final ReaderFontId fontFamily;
  final ReaderWeight fontWeight;
  final double lineHeight;
  final double paragraphSpacing;
  final double margin;
  final double letterSpacing;
  final TextAlign alignment;
  final double brightness;
  final PageTurnMode pageTurnMode;
  final bool verticalScroll;
  final bool oneHandMode;
  final bool leftHanded;
  final bool highContrast;
  final bool keepScreenAwake;

  const ReaderPreferences({
    this.theme = ReaderThemeId.light,
    this.fontSize = 17,
    this.fontFamily = ReaderFontId.serif,
    this.fontWeight = ReaderWeight.regular,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 12,
    this.margin = 20,
    this.letterSpacing = 0.0,
    this.alignment = TextAlign.justify,
    this.brightness = 1.0,
    this.pageTurnMode = PageTurnMode.slide,
    this.verticalScroll = true,
    this.oneHandMode = false,
    this.leftHanded = false,
    this.highContrast = false,
    this.keepScreenAwake = false,
  });

  ReaderPreferences copyWith({
    ReaderThemeId? theme,
    double? fontSize,
    ReaderFontId? fontFamily,
    ReaderWeight? fontWeight,
    double? lineHeight,
    double? paragraphSpacing,
    double? margin,
    double? letterSpacing,
    TextAlign? alignment,
    double? brightness,
    PageTurnMode? pageTurnMode,
    bool? verticalScroll,
    bool? oneHandMode,
    bool? leftHanded,
    bool? highContrast,
    bool? keepScreenAwake,
  }) {
    return ReaderPreferences(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      margin: margin ?? this.margin,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      alignment: alignment ?? this.alignment,
      brightness: brightness ?? this.brightness,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      verticalScroll: verticalScroll ?? this.verticalScroll,
      oneHandMode: oneHandMode ?? this.oneHandMode,
      leftHanded: leftHanded ?? this.leftHanded,
      highContrast: highContrast ?? this.highContrast,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    );
  }

  ReaderThemeSpec get themeSpec {
    for (final spec in readerThemeSpecs) {
      if (spec.id == theme) return spec;
    }
    return readerThemeSpecs.first;
  }

  double get effectiveFontSize =>
      highContrast ? fontSize + 2 : fontSize;

  TextStyle bodyStyle() {
    final base = _familyStyle();
    return (base ?? const TextStyle()).copyWith(
      fontSize: effectiveFontSize,
      fontWeight: _weightValue(),
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: highContrast ? Colors.black : themeSpec.text,
    );
  }

  TextStyle headingStyle(int level) {
    final base = _familyStyle();
    final sizes = [effectiveFontSize * 1.5, effectiveFontSize * 1.3, effectiveFontSize * 1.15];
    final size = sizes[(level - 1).clamp(0, sizes.length - 1)];
    return (base ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.bold,
      height: 1.3,
      letterSpacing: letterSpacing,
      color: highContrast ? Colors.black : themeSpec.text,
    );
  }

  FontWeight _weightValue() {
    switch (fontWeight) {
      case ReaderWeight.regular:
        return FontWeight.normal;
      case ReaderWeight.medium:
        return FontWeight.w500;
      case ReaderWeight.semibold:
        return FontWeight.w600;
      case ReaderWeight.bold:
        return FontWeight.bold;
    }
  }

  TextStyle? _familyStyle() {
    switch (fontFamily) {
      case ReaderFontId.system:
        return null;
      case ReaderFontId.serif:
        return const TextStyle(fontFamily: 'serif');
      case ReaderFontId.sans:
        return const TextStyle(fontFamily: 'sans-serif');
      case ReaderFontId.monospace:
        return const TextStyle(fontFamily: 'monospace');
      case ReaderFontId.dyslexic:
        return GoogleFonts.comicNeue();
    }
  }
}

class ReaderPreferencesNotifier extends StateNotifier<ReaderPreferences> {
  final Ref _ref;

  ReaderPreferencesNotifier(this._ref) : super(const ReaderPreferences());

  Future<void> load() async {
    final prefs = await _ref.read(sharedPrefsForReaderProvider.future);
    state = ReaderPreferences(
      theme: _enumFrom<ReaderThemeId>(prefs.getInt('reader_theme'), ReaderThemeId.values) ?? state.theme,
      fontSize: prefs.getDouble('reader_font_size') ?? state.fontSize,
      fontFamily: _enumFrom<ReaderFontId>(prefs.getInt('reader_font_family'), ReaderFontId.values) ?? state.fontFamily,
      fontWeight: _enumFrom<ReaderWeight>(prefs.getInt('reader_font_weight'), ReaderWeight.values) ?? state.fontWeight,
      lineHeight: prefs.getDouble('reader_line_height') ?? state.lineHeight,
      paragraphSpacing: prefs.getDouble('reader_paragraph_spacing') ?? state.paragraphSpacing,
      margin: prefs.getDouble('reader_margin') ?? state.margin,
      letterSpacing: prefs.getDouble('reader_letter_spacing') ?? state.letterSpacing,
      alignment: _alignFrom(prefs.getInt('reader_alignment')) ?? state.alignment,
      brightness: prefs.getDouble('reader_brightness') ?? state.brightness,
      pageTurnMode: _enumFrom<PageTurnMode>(prefs.getInt('reader_turn_mode'), PageTurnMode.values) ?? state.pageTurnMode,
      verticalScroll: prefs.getBool('reader_vertical_scroll') ?? state.verticalScroll,
      oneHandMode: prefs.getBool('reader_one_hand') ?? state.oneHandMode,
      leftHanded: prefs.getBool('reader_left_handed') ?? state.leftHanded,
      highContrast: prefs.getBool('reader_high_contrast') ?? state.highContrast,
      keepScreenAwake: prefs.getBool('reader_keep_awake') ?? state.keepScreenAwake,
    );
  }

  Future<void> update(ReaderPreferences next) async {
    state = next;
    final prefs = await _ref.read(sharedPrefsForReaderProvider.future);
    await prefs.setInt('reader_theme', next.theme.index);
    await prefs.setDouble('reader_font_size', next.fontSize);
    await prefs.setInt('reader_font_family', next.fontFamily.index);
    await prefs.setInt('reader_font_weight', next.fontWeight.index);
    await prefs.setDouble('reader_line_height', next.lineHeight);
    await prefs.setDouble('reader_paragraph_spacing', next.paragraphSpacing);
    await prefs.setDouble('reader_margin', next.margin);
    await prefs.setDouble('reader_letter_spacing', next.letterSpacing);
    await prefs.setInt('reader_alignment', next.alignment.index);
    await prefs.setDouble('reader_brightness', next.brightness);
    await prefs.setInt('reader_turn_mode', next.pageTurnMode.index);
    await prefs.setBool('reader_vertical_scroll', next.verticalScroll);
    await prefs.setBool('reader_one_hand', next.oneHandMode);
    await prefs.setBool('reader_left_handed', next.leftHanded);
    await prefs.setBool('reader_high_contrast', next.highContrast);
    await prefs.setBool('reader_keep_awake', next.keepScreenAwake);
  }

  T? _enumFrom<T>(int? index, List<T> values) {
    if (index == null || index < 0 || index >= values.length) return null;
    return values[index];
  }

  TextAlign? _alignFrom(int? index) {
    if (index == null || index < 0 || index > TextAlign.values.length - 1) return null;
    return TextAlign.values[index];
  }
}

final sharedPrefsForReaderProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final readerPreferencesProvider = StateNotifierProvider<ReaderPreferencesNotifier, ReaderPreferences>((ref) {
  return ReaderPreferencesNotifier(ref);
});
