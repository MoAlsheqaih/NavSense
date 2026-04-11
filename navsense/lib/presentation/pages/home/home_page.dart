import 'package:flutter/material.dart';
import 'package:navsense/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/waypoint.dart';
import '../../../domain/usecases/compute_route_usecase.dart';
import '../../../services/routing/route_service.dart';
import '../beacon_scanner/beacon_scanner_page.dart';
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
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Simulation Mode',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.simulation,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Beacon Scanner',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BeaconScannerPage()),
            ),
          ),
        ],
      ),
      body: vm.state == HomeState.loading && vm.destinations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : vm.state == HomeState.error
              ? Center(
                  child: Text(vm.errorMessage ?? l10n.errorGeneric,
                      style: const TextStyle(color: Colors.red)))
              : _buildContent(context, vm, l10n),
    );
  }

  Widget _buildContent(
      BuildContext context, HomeViewModel vm, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Feature badge ──────────────────────────────────────────────
          const _FeatureBadge(
            icon: Icons.route,
            label: 'Dijkstra Routing  •  9 Real Rooms',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 20),

          // ── Start room ────────────────────────────────────────────────
          const _SectionLabel(
            icon: Icons.my_location,
            text: 'Starting From',
            color: AppTheme.accentColor,
          ),
          const SizedBox(height: 10),
          _RoomGrid(
            rooms: vm.destinations,
            selected: vm.selectedOrigin,
            accentColor: AppTheme.accentColor,
            onTap: vm.selectOrigin,
          ),
          const SizedBox(height: 20),

          // ── Destination room ──────────────────────────────────────────
          _SectionLabel(
            icon: Icons.flag,
            text: l10n.homeSelectDestination,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 10),
          _RoomGrid(
            rooms: vm.destinations,
            selected: vm.selectedDestination,
            accentColor: AppTheme.primaryColor,
            onTap: vm.selectDestination,
          ),
          const SizedBox(height: 24),

          // ── Route summary chip ────────────────────────────────────────
          if (vm.selectedOrigin != null && vm.selectedDestination != null)
            _RouteSummaryChip(
              from: vm.selectedOrigin!.name,
              to: vm.selectedDestination!.name,
            ),

          const SizedBox(height: 16),

          // ── Start button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: vm.state == HomeState.loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: vm.canStart
                        ? () async {
                            final nav = Navigator.of(context);
                            final plan = await vm.startNavigation();
                            if (!mounted) return;
                            if (plan != null) {
                              nav.pushNamed(
                                AppRoutes.navigation,
                                arguments: plan,
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.navigation),
                    label: Text(l10n.homeStartNavigation),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          if (!vm.canStart)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  vm.selectedOrigin == null
                      ? 'Select a starting room'
                      : l10n.homeNoDestination,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Room Grid ─────────────────────────────────────────────────────────────────

class _RoomGrid extends StatelessWidget {
  final List<Waypoint> rooms;
  final Waypoint? selected;
  final Color accentColor;
  final void Function(Waypoint) onTap;

  const _RoomGrid({
    required this.rooms,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: rooms.length,
      itemBuilder: (ctx, i) {
        final room = rooms[i];
        final isSelected = selected?.id == room.id;
        return GestureDetector(
          onTap: () => onTap(room),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.18)
                  : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accentColor : AppTheme.darkBorder,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.meeting_room,
                    size: 20,
                    color: isSelected ? accentColor : AppTheme.darkOnMuted),
                const SizedBox(height: 4),
                Text(
                  _shortName(room.name),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? accentColor : AppTheme.darkOnBg,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _shortName(String name) {
    // "Room 1 (Top-Left)" → "Room 1\nTop-Left"
    final match = RegExp(r'^(Room \d+)\s*\((.+)\)$').firstMatch(name);
    if (match != null) return '${match.group(1)}\n${match.group(2)}';
    return name;
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SectionLabel(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RouteSummaryChip extends StatelessWidget {
  final String from;
  final String to;

  const _RouteSummaryChip({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 10, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_shortName(from),
                style: const TextStyle(
                    color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.arrow_forward,
              size: 16, color: AppTheme.darkOnMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_shortName(to),
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.flag, size: 10, color: AppTheme.primaryColor),
        ],
      ),
    );
  }

  String _shortName(String name) {
    final match = RegExp(r'^(Room \d+)').firstMatch(name);
    return match?.group(1) ?? name;
  }
}
