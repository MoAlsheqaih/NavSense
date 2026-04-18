import 'package:flutter/material.dart';
import '../../../../domain/entities/route_plan.dart';
import '../../../../l10n/app_localizations.dart';

class InstructionsPanel extends StatelessWidget {
  final RouteStep? currentStep;
  final double distanceToNext;
  final int currentStepIndex;
  final int totalSteps;
  final bool isSimulationRunning;
  final double simulationSpeed;
  final VoidCallback? onToggleSimulation;
  final VoidCallback? onResetSimulation;
  final ValueChanged<double>? onSpeedChanged;

  /// Total metres remaining to destination (for the ETA card).
  final double remainingMeters;

  /// Estimated seconds to destination at current speed.
  final double etaSeconds;

  const InstructionsPanel({
    super.key,
    this.currentStep,
    this.distanceToNext = 0,
    this.currentStepIndex = 0,
    this.totalSteps = 0,
    this.isSimulationRunning = false,
    this.simulationSpeed = 1.0,
    this.onToggleSimulation,
    this.onResetSimulation,
    this.onSpeedChanged,
    this.remainingMeters = 0,
    this.etaSeconds = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.navigationHeading,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 24),
          _buildInstructionCard(l10n),
          const SizedBox(height: 16),
          _buildDistanceCard(l10n),
          const SizedBox(height: 16),
          _buildStepProgress(),
          const SizedBox(height: 16),
          _buildSimulationControls(),
          const Spacer(),
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(AppLocalizations l10n) {
    final direction = currentStep?.direction;
    final color = direction != null
        ? _getDirectionColor(direction)
        : Colors.grey;

    // AnimatedSwitcher key on direction so it cross-fades when step changes
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(direction),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                direction != null
                    ? _getDirectionIcon(direction)
                    : Icons.hourglass_empty,
                key: ValueKey(direction),
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              direction != null
                  ? _getLocalizedInstruction(l10n, direction)
                  : l10n.homeComputingRoute,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceCard(AppLocalizations l10n) {
    final etaMinutes = (etaSeconds / 60).floor();
    final etaSecs = (etaSeconds % 60).floor();
    final etaLabel = etaMinutes > 0
        ? '${etaMinutes}m ${etaSecs}s'
        : '${etaSecs}s';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Distance to next waypoint
          _MetricTile(
            label: 'Next turn',
            value: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: distanceToNext, end: distanceToNext),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (_, v, __) =>
                  Text('${v.toStringAsFixed(1)} m',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          // Total remaining
          _MetricTile(
            label: 'Remaining',
            value: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                  begin: remainingMeters, end: remainingMeters),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (_, v, __) =>
                  Text('${v.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          // ETA
          _MetricTile(
            label: 'ETA',
            value: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                etaLabel,
                key: ValueKey(etaLabel),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    if (totalSteps == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No route computed yet',
          style: TextStyle(fontSize: 13, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${currentStepIndex + 1} of $totalSteps',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                '${((currentStepIndex / totalSteps.clamp(1, 999)) * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: totalSteps > 0 ? currentStepIndex / totalSteps : 0.0,
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey.shade300,
                color: Colors.blue,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Step dots
          Row(
            children: List.generate(totalSteps.clamp(0, 12), (i) {
              final isDone = i < currentStepIndex;
              final isCurrent = i == currentStepIndex;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: isCurrent ? 8 : 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isDone
                        ? Colors.blue
                        : isCurrent
                            ? Colors.blue.shade700
                            : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simulation Controls',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  key: ValueKey(isSimulationRunning),
                  onPressed: onToggleSimulation,
                  icon: Icon(
                    isSimulationRunning ? Icons.pause : Icons.play_arrow,
                    color: isSimulationRunning ? Colors.orange : Colors.green,
                  ),
                  tooltip: isSimulationRunning ? 'Pause' : 'Play',
                  iconSize: 20,
                ),
              ),
              IconButton(
                onPressed: onResetSimulation,
                icon: const Icon(Icons.refresh, color: Colors.blue),
                tooltip: 'Reset',
                iconSize: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speed: ${simulationSpeed.toStringAsFixed(1)}x',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Slider(
                      value: simulationSpeed,
                      min: 0.1,
                      max: 3.0,
                      divisions: 29,
                      onChanged: onSpeedChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isSimulationRunning ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isSimulationRunning ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isSimulationRunning ? 'Simulation Running' : 'Simulation Mode',
              key: ValueKey(isSimulationRunning),
              style: TextStyle(
                fontSize: 12,
                color: isSimulationRunning ? Colors.green : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedInstruction(AppLocalizations l10n, TurnDirection d) {
    switch (d) {
      case TurnDirection.left:     return l10n.instruction_turn_left;
      case TurnDirection.right:    return l10n.instruction_turn_right;
      case TurnDirection.straight: return l10n.instruction_go_straight;
      case TurnDirection.arrived:    return l10n.instruction_arrived;
      case TurnDirection.turnAround: return 'Turn Around';
    }
  }

  IconData _getDirectionIcon(TurnDirection d) {
    switch (d) {
      case TurnDirection.left:       return Icons.turn_left;
      case TurnDirection.right:      return Icons.turn_right;
      case TurnDirection.straight:   return Icons.arrow_upward;
      case TurnDirection.arrived:    return Icons.check_circle;
      case TurnDirection.turnAround: return Icons.u_turn_left;
    }
  }

  Color _getDirectionColor(TurnDirection d) {
    switch (d) {
      case TurnDirection.left:       return Colors.orange;
      case TurnDirection.right:      return Colors.purple;
      case TurnDirection.straight:   return Colors.blue;
      case TurnDirection.arrived:    return Colors.green;
      case TurnDirection.turnAround: return Colors.red;
    }
  }
}

// ── Helper widget ──────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label;
  final Widget value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        value,
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
