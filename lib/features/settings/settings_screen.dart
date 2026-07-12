import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/services/settings_service.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(title: const Text("Appearance"), subtitle: const Text("Theme, accent color, font")),
          SwitchListTile(title: const Text("Dark Mode"), value: settings.themeMode == ThemeMode.dark, onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light),
          ListTile(title: const Text("Reading"), subtitle: const Text("Default reader settings, font size, brightness"), onTap: () {}),
          ListTile(title: const Text("Privacy"), subtitle: const Text("Metadata sync, analytics, export data"), onTap: () {}),
          ListTile(title: const Text("Storage"), subtitle: const Text("Scan device, cache management"), onTap: () {}),
          ListTile(title: const Text("Account"), subtitle: const Text("Login, logout, profile"), onTap: () {}),
          ListTile(title: const Text("Notifications"), subtitle: const Text("Daily reminders, reading goals"), onTap: () {}),
          const Divider(),
          ListTile(title: const Text("Version"), subtitle: Text(AppConstants.appVersion)),
          ListTile(title: const Text("Licenses"), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
          ListTile(title: const Text("Privacy Policy"), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
          ListTile(title: const Text("Terms of Service"), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
        ],
      ),
    );
  }
}
