import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_theme.dart";
import "../../data/services/settings_service.dart";

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

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          _SectionHeader(title: "Appearance"),
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("Use dark theme"),
            secondary: Icon(settings.themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
              settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded),
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
          ListTile(
            leading: const Icon(Icons.text_fields_rounded),
            title: const Text("Font Scale"),
            subtitle: Text("${_fontScale.toStringAsFixed(1)}x"),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _fontScale,
                min: 0.7,
                max: 1.5,
                divisions: 8,
                label: _fontScale.toStringAsFixed(1),
                onChanged: (v) {
                  setState(() => _fontScale = v);
                  settings.setFontScale(v);
                },
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(title: "Reading"),
          ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: const Text("Default Font Size"),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _fontScale,
                min: 0.7,
                max: 1.5,
                divisions: 8,
                label: _fontScale.toStringAsFixed(1),
                onChanged: (v) {
                  setState(() => _fontScale = v);
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_medium_rounded),
            title: const Text("Brightness"),
            subtitle: Text("${(_brightness * 100).toInt()}%"),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _brightness,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: "${(_brightness * 100).toInt()}%",
                onChanged: (v) => setState(() => _brightness = v),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.space_bar_rounded),
            title: const Text("Margins"),
            subtitle: Text("${_margin.toInt()}px"),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _margin,
                min: 8,
                max: 32,
                divisions: 6,
                label: "${_margin.toInt()}px",
                onChanged: (v) => setState(() => _margin = v),
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(title: "Privacy"),
          SwitchListTile(
            title: const Text("Public Profile"),
            subtitle: const Text("Allow others to see your reading activity"),
            secondary: const Icon(Icons.public_rounded),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            title: const Text("Sync Metadata"),
            subtitle: const Text("Sync reading progress and bookmarks"),
            secondary: const Icon(Icons.sync_rounded),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            title: const Text("Analytics"),
            subtitle: const Text("Help improve Bookstr with usage data"),
            secondary: const Icon(Icons.analytics_rounded),
            value: false,
            onChanged: (v) {},
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text("Export Data"),
            subtitle: const Text("Export your reading data"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          const Divider(),
          _SectionHeader(title: "Account"),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: const Text("Profile"),
            subtitle: const Text("Edit your profile information"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppConstants.routeProfile),
          ),
          ListTile(
            leading: const Icon(Icons.login_rounded),
            title: const Text("Sign In / Sign Up"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppConstants.routeAuth),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: Text("Logout", style: TextStyle(color: colorScheme.error)),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go(AppConstants.routeHome);
            },
          ),
          const Divider(),
          _SectionHeader(title: "Storage"),
          ListTile(
            leading: const Icon(Icons.scan_rounded),
            title: const Text("Scan Device for Books"),
            subtitle: const Text("Find local EPUB and PDF files"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: const Text("Clear Cache"),
            subtitle: const Text("Free up storage space"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          const Divider(),
          _SectionHeader(title: "About"),
          appInfo.when(
            data: (info) => ListTile(
              leading: const Icon(Icons.info_rounded),
              title: const Text("Version"),
              subtitle: Text("${info.versionName} (${info.buildNumber})"),
            ),
            loading: () => ListTile(leading: const Icon(Icons.info_rounded), title: const Text("Version"), subtitle: const Text("...")),
            error: (_, __) => ListTile(leading: const Icon(Icons.info_rounded), title: const Text("Version"), subtitle: Text(AppConstants.appVersion)),
          ),
          ListTile(
            leading: const Icon(Icons.description_rounded),
            title: const Text("Open Source Licenses"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(context: context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _launchUrl("https://bookstr.app/privacy"),
          ),
          ListTile(
            leading: const Icon(Icons.article_rounded),
            title: const Text("Terms of Service"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _launchUrl("https://bookstr.app/terms"),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _accentColorName(Color color) {
    if (color == AppTheme.primaryLight) return "Blue";
    if (color == const Color(0xFF34A853)) return "Green";
    if (color == const Color(0xFFEA4335)) return "Red";
    if (color == const Color(0xFFFBBC04)) return "Yellow";
    if (color == const Color(0xFF7C4DFF)) return "Purple";
    if (color == const Color(0xFFFF6D00)) return "Orange";
    if (color == const Color(0xFFE91E63)) return "Pink";
    return "Custom";
  }

  void _showAccentColorPicker(SettingsService settings) {
    final colors = [
      AppTheme.primaryLight,
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
                  boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)] : null,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
