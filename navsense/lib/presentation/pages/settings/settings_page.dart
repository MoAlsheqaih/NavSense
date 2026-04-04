import 'package:flutter/material.dart';
import 'package:navsense/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'settings_viewmodel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          // ── Language ──────────────────────────────────────────────────
          _SectionHeader(title: l10n.settingsLanguage),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(
              vm.isArabic
                  ? l10n.settingsLanguageArabic
                  : l10n.settingsLanguageEnglish,
            ),
            trailing: Switch(
              value: vm.isArabic,
              onChanged: (_) => vm.toggleLanguage(),
              activeThumbColor: Theme.of(context).primaryColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              vm.isArabic
                  ? '← Arabic (RTL) active'
                  : 'English (LTR) active →',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const Divider(),

          // ── About ────────────────────────────────────────────────────
          _SectionHeader(title: l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsDescription),
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: Text(l10n.settingsVersion),
          ),

        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

