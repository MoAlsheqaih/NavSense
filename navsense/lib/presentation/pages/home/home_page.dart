import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/compute_route_usecase.dart';
import '../../../services/routing/route_service.dart';
import 'home_viewmodel.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        GetIt.I<ComputeRouteUseCase>(),
        GetIt.I<RouteService>(),
      )..loadDestinations(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeSelectDestination,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (vm.state == HomeState.loading && vm.destinations.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (vm.state == HomeState.error)
              Center(
                child: Text(
                  vm.errorMessage ?? l10n.errorGeneric,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: vm.destinations.length,
                  itemBuilder: (ctx, i) {
                    final dest = vm.destinations[i];
                    final isSelected = vm.selectedDestination == dest;
                    return GestureDetector(
                      onTap: () => vm.selectDestination(dest),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.18)
                              : AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.darkBorder,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.darkOnMuted,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dest.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.darkOnBg,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${l10n.homeFloor} ${dest.floor}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? AppTheme.primaryColor.withOpacity(0.8)
                                    : AppTheme.darkOnMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            if (vm.state == HomeState.loading && vm.destinations.isNotEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                onPressed: vm.selectedDestination == null
                    ? null
                    : () async {
                        final plan = await vm.startNavigation();
                        if (plan != null && mounted) {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.navigation,
                            arguments: plan,
                          );
                        }
                      },
                icon: const Icon(Icons.navigation),
                label: Text(l10n.homeStartNavigation),
              ),
            if (vm.selectedDestination == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    l10n.homeNoDestination,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
