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
          ),
          const SizedBox(height: 24),
          _buildInstructionCard(context, l10n),
          const SizedBox(height: 16),
          _buildDistanceCard(context, l10n),
          const SizedBox(height: 16),
          _buildStepIndicator(context, l10n),
          const SizedBox(height: 16),
          _buildSimulationControls(context),
          const Spacer(),
          _buildStatusIndicator(context),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(BuildContext context, AppLocalizations l10n) {
    final instruction = currentStep != null
        ? _getLocalizedInstruction(l10n, currentStep!.direction)
        : l10n.homeComputingRoute;

    final icon = currentStep != null
        ? _getDirectionIcon(currentStep!.direction)
        : Icons.hourglass_empty;

    final color = currentStep != null
        ? _getDirectionColor(currentStep!.direction)
        : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            instruction,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.navigationDistanceLabel,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            l10n.navigationMeters(distanceToNext.toStringAsFixed(1)),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.navigationStepOf(currentStepIndex + 1, totalSteps),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationControls(BuildContext context) {
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: onToggleSimulation,
                icon: Icon(
                  isSimulationRunning ? Icons.pause : Icons.play_arrow,
                  color: isSimulationRunning ? Colors.orange : Colors.green,
                ),
                tooltip: isSimulationRunning ? 'Pause' : 'Play',
                iconSize: 20,
              ),
              IconButton(
                onPressed: onResetSimulation,
                icon: const Icon(Icons.refresh, color: Colors.blue),
                tooltip: 'Reset',
                iconSize: 20,
              ),
              const SizedBox(width: 12),
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

  Widget _buildStatusIndicator(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isSimulationRunning ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isSimulationRunning ? 'Simulation Running' : 'Simulation Mode',
            style: TextStyle(
              fontSize: 12,
              color: isSimulationRunning ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedInstruction(
    AppLocalizations l10n,
    TurnDirection direction,
  ) {
    switch (direction) {
      case TurnDirection.left:
        return l10n.instruction_turn_left;
      case TurnDirection.right:
        return l10n.instruction_turn_right;
      case TurnDirection.straight:
        return l10n.instruction_go_straight;
      case TurnDirection.arrived:
        return l10n.instruction_arrived;
    }
  }

  IconData _getDirectionIcon(TurnDirection direction) {
    switch (direction) {
      case TurnDirection.left:
        return Icons.turn_left;
      case TurnDirection.right:
        return Icons.turn_right;
      case TurnDirection.straight:
        return Icons.arrow_upward;
      case TurnDirection.arrived:
        return Icons.check_circle;
    }
  }

  Color _getDirectionColor(TurnDirection direction) {
    switch (direction) {
      case TurnDirection.left:
        return Colors.orange;
      case TurnDirection.right:
        return Colors.purple;
      case TurnDirection.straight:
        return Colors.blue;
      case TurnDirection.arrived:
        return Colors.green;
    }
  }
}
