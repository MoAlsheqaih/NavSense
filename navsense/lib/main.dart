import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'presentation/pages/settings/settings_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register all services and repositories (SR-ARCH-03).
  await setupServiceLocator();

  // Initialize settings (locale) before app starts.
  final settingsVm = SettingsViewModel();
  await settingsVm.initialize();

  runApp(
    ChangeNotifierProvider<SettingsViewModel>.value(
      value: settingsVm,
      child: const NavSenseApp(),
    ),
  );
}
