import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/services/settings_service.dart";
import "../../data/services/storage_service.dart";

final _appInfoProvider = FutureProvider.autoDispose<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _fontScale = 1.0;
  double _brightness = 0.8;
  double _margin = 16.0;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _fontScale = settings.fontScale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsServiceProvider);
    final appInfo = ref.watch(_appInfoProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final publicProfile = ref.watch(publicProfileProvider);
    final syncMetadata = ref.watch(syncMetadataProvider);
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: "Appearance"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  subtitle: const Text("Use dark theme"),
                  secondary: Icon(settings.themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.accent),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (v) {
                    ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
                    settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.palette_rounded, color: AppColors.accent),
                  title: const Text("Accent Color"),
                  subtitle: Text(_accentColorName(settings.seedColor)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: settings.seedColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => _showAccentColorPicker(settings),
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.text_fields_rounded, color: AppColors.accent),
                  title: const Text("Font Scale"),
                  subtitle: Text("${_fontScale.toStringAsFixed(1)}x"),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: _fontScale,
                      min: 0.7,
                      max: 1.5,
                      divisions: 8,
                      activeColor: AppColors.accent,
                      label: _fontScale.toStringAsFixed(1),
                      onChanged: (v) {
                        setState(() => _fontScale = v);
                        settings.setFontScale(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: "Reading"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.format_size_rounded, color: AppColors.accent),
                  title: const Text("Default Font Size"),
                  subtitle: Text("${_fontSize.toInt()}pt"),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 24,
                      divisions: 12,
                      activeColor: AppColors.accent,
                      label: "${_fontSize.toInt()}pt",
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        ref.read(fontSizeProvider.notifier).state = v;
                      },
                    ),
                  ),
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.brightness_medium_rounded, color: AppColors.accent),
                  title: const Text("Brightness"),
                  subtitle: Text("${(_brightness * 100).toInt()}%"),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: _brightness,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      activeColor: AppColors.accent,
                      label: "${(_brightness * 100).toInt()}%",
                      onChanged: (v) {
                        setState(() => _brightness = v);
                        ref.read(brightnessProvider.notifier).state = v;
                      },
                    ),
                  ),
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.space_bar_rounded, color: AppColors.accent),
                  title: const Text("Margins"),
                  subtitle: Text("${_margin.toInt()}px"),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: _margin,
                      min: 8,
                      max: 32,
                      divisions: 6,
                      activeColor: AppColors.accent,
                      label: "${_margin.toInt()}px",
                      onChanged: (v) {
                        setState(() => _margin = v);
                        ref.read(marginProvider.notifier).state = v;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: "Privacy"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Public Profile"),
                  subtitle: const Text("Allow others to see your reading activity"),
                  secondary: const Icon(Icons.public_rounded, color: AppColors.accent),
                  value: publicProfile,
                  onChanged: (v) async {
                    ref.read(publicProfileProvider.notifier).state = v;
                    final prefs = await ref.read(sharedPreferencesProvider.future);
                    await prefs.setBool('public_profile', v);
                  },
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                SwitchListTile(
                  title: const Text("Sync Metadata"),
                  subtitle: const Text("Sync reading progress and bookmarks"),
                  secondary: const Icon(Icons.sync_rounded, color: AppColors.accent),
                  value: syncMetadata,
                  onChanged: (v) async {
                    ref.read(syncMetadataProvider.notifier).state = v;
                    final prefs = await ref.read(sharedPreferencesProvider.future);
                    await prefs.setBool('sync_metadata', v);
                  },
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                SwitchListTile(
                  title: const Text("Analytics"),
                  subtitle: const Text("Help improve Libora with usage data"),
                  secondary: const Icon(Icons.analytics_rounded, color: AppColors.accent),
                  value: analytics,
                  onChanged: (v) async {
                    ref.read(analyticsProvider.notifier).state = v;
                    final prefs = await ref.read(sharedPreferencesProvider.future);
                    await prefs.setBool('analytics', v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: "Account"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: AppColors.accent),
                  title: const Text("Profile"),
                  subtitle: const Text("Edit your profile information"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppConstants.routeProfile),
                ),
                if (!isAuthenticated) ...[
                  Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                  ListTile(
                    leading: const Icon(Icons.login_rounded, color: AppColors.accent),
                    title: const Text("Sign In / Sign Up"),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppConstants.routeAuth),
                  ),
                ],
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: Text("Logout", style: TextStyle(color: colorScheme.error)),
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go(AppConstants.routeHome);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: "Storage"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: AppColors.accent),
                  title: const Text("Clear Cache"),
                  subtitle: const Text("Free up storage space"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Clear Cache"),
                        content: const Text("This will clear all cached data. Your books and reading data will not be affected."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Clear")),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await StorageService.clearAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cache cleared successfully")),
                        );
                      }
                    }
                  },
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppColors.accent),
                  title: const Text("Export Data"),
                  subtitle: const Text("Export your reading data"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Export Data"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.code_rounded),
                              title: const Text("Export as JSON"),
                              onTap: () {
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.table_chart_rounded),
                              title: const Text("Export as CSV"),
                              onTap: () {
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: "About"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                appInfo.when(
                  data: (info) => ListTile(
                    leading: const Icon(Icons.info_rounded, color: AppColors.accent),
                    title: const Text("Version"),
                    subtitle: Text("${info.version} (${info.buildNumber})"),
                  ),
                  loading: () => ListTile(
                    leading: const Icon(Icons.info_rounded, color: AppColors.accent),
                    title: const Text("Version"),
                    subtitle: const Text("..."),
                  ),
                  error: (_, __) => ListTile(
                    leading: const Icon(Icons.info_rounded, color: AppColors.accent),
                    title: const Text("Version"),
                    subtitle: Text(AppConstants.appVersion),
                  ),
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.description_rounded, color: AppColors.accent),
                  title: const Text("Open Source Licenses"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(context: context),
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded, color: AppColors.accent),
                  title: const Text("Privacy Policy"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _launchUrl("https://libora.app/privacy"),
                ),
                Divider(height: 1, indent: 72, color: theme.colorScheme.outline.withOpacity(0.3)),
                ListTile(
                  leading: const Icon(Icons.article_rounded, color: AppColors.accent),
                  title: const Text("Terms of Service"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _launchUrl("https://libora.app/terms"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _accentColorName(Color color) {
    if (color == const Color(0xFFE53935)) return "Crimson";
    if (color == const Color(0xFF1A73E8)) return "Blue";
    if (color == const Color(0xFF34A853)) return "Green";
    if (color == const Color(0xFFEA4335)) return "Red";
    if (color == const Color(0xFFFBBC04)) return "Yellow";
    if (color == const Color(0xFF7C4DFF)) return "Purple";
    if (color == const Color(0xFFFF6D00)) return "Orange";
    if (color == const Color(0xFFE91E63)) return "Pink";
    if (color == const Color(0xFF00BCD4)) return "Cyan";
    return "Custom";
  }

  void _showAccentColorPicker(SettingsService settings) {
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFF1A73E8),
      const Color(0xFF34A853),
      const Color(0xFFEA4335),
      const Color(0xFFFBBC04),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF6D00),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accent Color"),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final selected = settings.seedColor == c;
            return GestureDetector(
              onTap: () {
                settings.setSeedColor(c);
                ref.read(seedColorProvider.notifier).state = c;
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: selected ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)] : null,
                ),
                child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
