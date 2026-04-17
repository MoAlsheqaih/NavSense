import 'package:flutter/material.dart';
import 'package:navsense/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/route_plan.dart';
import '../../../services/ble/ble_service.dart';
import '../../../services/haptic/haptic_service.dart';
import '../../../services/haptic/wearable_haptic_service.dart';
import '../../../services/logging/session_logging_service.dart';
import '../../widgets/direction_card.dart';
import 'navigation_viewmodel.dart';

class NavigationPage extends StatelessWidget {
  final RoutePlan? routePlan;
  final bool useSimulation;

  const NavigationPage({
    Key? key,
    this.routePlan,
    this.useSimulation = false,
  }) : super(key: key);

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
        wearableHapticService: GetIt.I<WearableHapticService>(),
        loggingService: GetIt.I<SessionLoggingService>(),
        useSimulation: useSimulation,
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
    final instruction = _localizeInstruction(step.instruction, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navigationHeading),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final nav = Navigator.of(context);
            await vm.cancelNavigation();
            if (mounted) nav.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // ── Step counter ───────────────────────────────────
                    Text(
                      l10n.navigationStepOf(
                          vm.currentStepIndex + 1, vm.totalSteps),
                      style: const TextStyle(color: AppTheme.darkOnMuted),
                    ),
                    const SizedBox(height: 10),

                    // ── Direction card ─────────────────────────────────
                    DirectionCard(
                        direction: step.direction, instruction: instruction),
                    const SizedBox(height: 16),

                    // ── Beacon panel ───────────────────────────────────
                    _BeaconPanel(
                      isConnected: vm.isConnected,
                      rssi: vm.lastRssi,
                      distanceMeters: vm.lastDistanceMeters,
                      strength: vm.signalStrength,
                    ),
                    const SizedBox(height: 16),

                    // ── Route steps plan ───────────────────────────────
                    _RouteStepsList(
                      steps: vm.routePlan.steps,
                      currentIndex: vm.currentStepIndex,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Action buttons ─────────────────────────────────────────
            _ActionBar(vm: vm, l10n: l10n),
          ],
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

  void _showArrivedDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Icon(Icons.flag, color: Colors.green, size: 48),
        content: Text(l10n.instruction_arrived,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Beacon Panel ──────────────────────────────────────────────────────────────

class _BeaconPanel extends StatelessWidget {
  final bool isConnected;
  final int rssi;
  final double? distanceMeters;
  final String strength;

  const _BeaconPanel({
    required this.isConnected,
    required this.rssi,
    required this.distanceMeters,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppTheme.successColor : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_searching,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'BLE Beacon  •  Holy-IOT',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              _StrengthBadge(strength: strength, isConnected: isConnected),
            ],
          ),
          if (isConnected) ...[
            const SizedBox(height: 12),
            // Metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BeaconMetric(
                  label: 'RSSI',
                  value: '$rssi dBm',
                  icon: Icons.signal_cellular_alt,
                  color: color,
                ),
                _BeaconMetric(
                  label: 'Distance',
                  value: distanceMeters != null
                      ? '${distanceMeters!.toStringAsFixed(1)} m'
                      : '—',
                  icon: Icons.straighten,
                  color: AppTheme.primaryColor,
                ),
                _BeaconMetric(
                  label: 'Signal',
                  value: strength,
                  icon: Icons.wifi,
                  color: _strengthColor(strength),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Scanning for beacon…',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Color _strengthColor(String s) {
    switch (s) {
      case 'VERY CLOSE':
        return Colors.green;
      case 'CLOSE':
        return Colors.lightGreen;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

class _StrengthBadge extends StatelessWidget {
  final String strength;
  final bool isConnected;

  const _StrengthBadge({required this.strength, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? _color() : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isConnected ? strength : 'SEARCHING',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _color() {
    switch (strength) {
      case 'VERY CLOSE':
        return Colors.green;
      case 'CLOSE':
        return Colors.lightGreen;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

class _BeaconMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BeaconMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: AppTheme.darkOnMuted, fontSize: 11)),
      ],
    );
  }
}

// ── Route Steps List ──────────────────────────────────────────────────────────

class _RouteStepsList extends StatelessWidget {
  final List<RouteStep> steps;
  final int currentIndex;
  final AppLocalizations l10n;

  const _RouteStepsList({
    required this.steps,
    required this.currentIndex,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Dijkstra Route  •  ${steps.length} steps',
                style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            final isDone = i < currentIndex;
            final isCurrent = i == currentIndex;
            return _StepRow(
              step: step,
              index: i,
              isDone: isDone,
              isCurrent: isCurrent,
              l10n: l10n,
            );
          }),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final RouteStep step;
  final int index;
  final bool isDone;
  final bool isCurrent;
  final AppLocalizations l10n;

  const _StepRow({
    required this.step,
    required this.index,
    required this.isDone,
    required this.isCurrent,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? Colors.grey.shade600
        : isCurrent
            ? AppTheme.primaryColor
            : AppTheme.darkOnMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Step icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? Colors.grey.shade800
                  : isCurrent
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.darkCard,
              border: Border.all(
                color: isDone ? Colors.grey.shade700 : color,
                width: isCurrent ? 1.5 : 1,
              ),
            ),
            child: Icon(_stepIcon(step.direction),
                size: 14, color: isDone ? Colors.grey.shade600 : color),
          ),
          const SizedBox(width: 10),
          // Instruction
          Expanded(
            child: Text(
              _localizeInstruction(step.instruction, l10n),
              style: TextStyle(
                color: color,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          // Distance
          Text(
            '${step.distanceMeters.toStringAsFixed(1)} m',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  IconData _stepIcon(TurnDirection d) {
    switch (d) {
      case TurnDirection.left:
        return Icons.turn_left;
      case TurnDirection.right:
        return Icons.turn_right;
      case TurnDirection.straight:
        return Icons.straight;
      case TurnDirection.arrived:
        return Icons.flag;
    }
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
      default:
        return key;
    }
  }
}

// ── Action Bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final NavigationViewModel vm;
  final AppLocalizations l10n;

  const _ActionBar({required this.vm, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.triggerOffRoute,
                  icon: const Icon(Icons.warning_amber,
                      color: AppTheme.warningColor, size: 16),
                  label: const Text('Off-Route',
                      style: TextStyle(color: AppTheme.warningColor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.warningColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: vm.status == NavigationStatus.active
                      ? vm.advanceManually
                      : null,
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Next Step'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await vm.cancelNavigation();
              nav.pop();
            },
            child: Text(l10n.navigationCancel,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
