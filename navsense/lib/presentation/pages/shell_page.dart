import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/theme/app_theme.dart';
import 'home/home_page.dart';
import 'session_history/session_history_page.dart';
import 'settings/settings_page.dart';

/// Persistent shell with custom bottom navigation.
/// Uses IndexedStack so each tab preserves its state.
/// Avoids BottomNavigationBar which requires Overlay (Flutter 3.3 web issue).
class ShellPage extends StatefulWidget {
  const ShellPage({Key? key}) : super(key: key);

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    SessionHistoryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _CustomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        labels: [l10n.navHome, l10n.navHistory, l10n.navSettings],
        icons: const [Icons.home, Icons.history, Icons.settings],
      ),
    );
  }
}

class _CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;
  final List<IconData> icons;

  const _CustomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.labels,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(icons.length, (i) {
              final selected = i == selectedIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[i],
                        color: selected
                            ? AppTheme.primaryColor
                            : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? AppTheme.primaryColor
                              : Colors.grey,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
