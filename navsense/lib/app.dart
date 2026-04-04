import 'package:flutter/material.dart';
import 'package:navsense/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/settings/settings_viewmodel.dart';

class NavSenseApp extends StatelessWidget {
  const NavSenseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (_, settingsVm, __) {
        return MaterialApp(
          title: 'NavSense',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,

          // ── Localization (SR-UI-01, SR-UI-03) ─────────────────────────
          locale: settingsVm.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // ── Routing ───────────────────────────────────────────────────
          // Shell is the initial route; navigation page pushes on top.
          initialRoute: AppRoutes.shell,
          onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}
