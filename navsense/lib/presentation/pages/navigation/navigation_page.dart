import 'package:flutter/material.dart';
import 'package:navsense/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/route_plan.dart';
import '../../../services/ble/ble_service.dart';
import '../../../services/haptic/haptic_service.dart';
import '../../../services/logging/session_logging_service.dart';
import '../../widgets/ble_status_widget.dart';
import '../../widgets/direction_card.dart';
import 'navigation_viewmodel.dart';

class NavigationPage extends StatelessWidget {
  final RoutePlan? routePlan;

  const NavigationPage({Key? key, this.routePlan}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final plan = routePlan;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigation')),
        body: const Center(child: Text('No route plan provided.')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => NavigationViewModel(
        routePlan: plan,
        bleService: GetIt.I<BleService>(),
        hapticService: GetIt.I<HapticService>(),
        loggingService: GetIt.I<SessionLoggingService>(),
      )..initialize(),
      child: const _NavigationView(),
    );
  }
}

class _NavigationView extends StatefulWidget {
  const _NavigationView();

  @override
  State<_NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<_NavigationView> {
  bool _arrivedDialogShown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<NavigationViewModel>();

    if (vm.status == NavigationStatus.arrived && !_arrivedDialogShown) {
      _arrivedDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showArrivedDialog(context, l10n);
      });
    }

    final step = vm.currentStep;
    final localizedInstruction =
        _localizeInstruction(step.instruction, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navigationHeading),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await vm.cancelNavigation();
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Step counter
              Text(
                l10n.navigationStepOf(
                    vm.currentStepIndex + 1, vm.totalSteps),
                style: const TextStyle(color: AppTheme.darkOnMuted),
              ),
              const SizedBox(height: 12),

              // Direction card
              DirectionCard(
                direction: step.direction,
                instruction: localizedInstruction,
              ),

              const SizedBox(height: 20),

              // Distance + haptic row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoChip(
                    icon: Icons.straighten,
                    label: l10n.navigationDistanceLabel,
                    value: l10n.navigationMeters(
                        vm.currentDistance.toStringAsFixed(1)),
                  ),
                  _InfoChip(
                    icon: Icons.vibration,
                    label: l10n.navigationHapticLabel,
                    value: vm.lastHapticLabel != null
                        ? _localizeHapticLabel(vm.lastHapticLabel!, l10n)
                        : '—',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // BLE status
              BleStatusWidget(
                isConnected: vm.isConnected,
                connectedLabel: l10n.navigationBleConnected,
                searchingLabel: l10n.navigationBleDisconnected,
              ),

              const Spacer(),

              // Off-route trigger
              OutlinedButton.icon(
                onPressed: vm.triggerOffRoute,
                icon: const Icon(Icons.warning_amber, color: AppTheme.warningColor),
                label: Text(
                  l10n.instruction_off_route,
                  style: const TextStyle(color: AppTheme.warningColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.warningColor),
                ),
              ),
              const SizedBox(height: 8),

              // Manual step advance for demo
              ElevatedButton.icon(
                onPressed: vm.status == NavigationStatus.active
                    ? vm.advanceManually
                    : null,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next Step (Demo)'),
              ),
              const SizedBox(height: 8),

              // Cancel
              TextButton(
                onPressed: () async {
                  await vm.cancelNavigation();
                  if (mounted) Navigator.pop(context);
                },
                child: Text(
                  l10n.navigationCancel,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizeInstruction(String key, AppLocalizations l10n) {
    switch (key) {
      case 'instruction_go_straight':
        return l10n.instruction_go_straight;
      case 'instruction_turn_left':
        return l10n.instruction_turn_left;
      case 'instruction_turn_right':
        return l10n.instruction_turn_right;
      case 'instruction_arrived':
        return l10n.instruction_arrived;
      case 'instruction_off_route':
        return l10n.instruction_off_route;
      default:
        return key;
    }
  }

  String _localizeHapticLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'hapticLeft':
        return l10n.hapticLeft;
      case 'hapticRight':
        return l10n.hapticRight;
      case 'hapticArrival':
        return l10n.hapticArrival;
      case 'hapticOffRoute':
        return l10n.hapticOffRoute;
      default:
        return key;
    }
  }

  void _showArrivedDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Icon(Icons.flag, color: Colors.green, size: 48),
        content: Text(
          l10n.instruction_arrived,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.darkOnMuted),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.darkOnMuted)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.darkOnBg)),
      ],
    );
  }
}
