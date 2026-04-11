import 'package:flutter/material.dart';

import '../../domain/entities/route_plan.dart';
import '../../presentation/pages/navigation/navigation_page.dart';
import '../../presentation/pages/shell_page.dart';
import '../../presentation/pages/simulation/simulation_map_page.dart';

class AppRoutes {
  AppRoutes._();
  static const String shell = '/';
  static const String navigation = '/navigation';
  static const String simulation = '/simulation';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.shell:
        return MaterialPageRoute(builder: (_) => const ShellPage());

      case AppRoutes.navigation:
        final plan = settings.arguments as RoutePlan?;
        return MaterialPageRoute(
          builder: (_) => NavigationPage(routePlan: plan),
        );

      case AppRoutes.simulation:
        return MaterialPageRoute(
          builder: (_) => const SimulationMapPage(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route for ${settings.name}')),
          ),
        );
    }
  }
}
