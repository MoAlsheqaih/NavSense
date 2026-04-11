import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/entities/route_plan.dart';
import '../../../../domain/entities/waypoint.dart';
import '../../../../l10n/app_localizations.dart';
import 'widgets/instructions_panel.dart';
import 'widgets/simulation_map_widget.dart';

class SimulationMapPage extends StatefulWidget {
  const SimulationMapPage({super.key});

  @override
  State<SimulationMapPage> createState() => _SimulationMapPageState();
}

class _SimulationMapPageState extends State<SimulationMapPage> {
  Waypoint? _origin;
  Waypoint? _destination;
  RoutePlan? _routePlan;
  RouteStep? _currentStep;
  double _distanceToNext = 0.0;
  Waypoint? _customerPosition;

  // Simulation controls
  bool _isSimulationRunning = false;
  double _simulationSpeed = 1.0;
  Timer? _simulationTimer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulation Mode'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSimulation,
            tooltip: 'Reset Simulation',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel: Instructions
          SizedBox(
            width: 320,
            child: InstructionsPanel(
              currentStep: _currentStep,
              distanceToNext: _distanceToNext,
              currentStepIndex: _getCurrentStepIndex(),
              totalSteps: _routePlan?.steps.length ?? 0,
              isSimulationRunning: _isSimulationRunning,
              simulationSpeed: _simulationSpeed,
              onToggleSimulation: _toggleSimulation,
              onResetSimulation: _resetSimulation,
              onSpeedChanged: _onSpeedChanged,
            ),
          ),

          // Right panel: Interactive map
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Map header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Floor Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '50m × 29m (0.5m cells)',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Legend
                  Row(
                    children: [
                      _buildLegendItem(Colors.blue, 'Customer Position'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.green, 'Destination'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.red, 'Route Path'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.grey.shade400, 'Waypoints'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Interactive map
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SimulationMapWidget(
                        origin: _customerPosition ?? _origin,
                        destination: _destination,
                        routePlan: _routePlan,
                        onOriginChanged: _onOriginChanged,
                        onDestinationChanged: _onDestinationChanged,
                        onRouteChanged: _onRouteChanged,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Instructions text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Instructions:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. Tap once on map to set customer position (blue dot)\n'
                          '2. Tap again to set destination (green dot)\n'
                          '3. Route will be calculated automatically\n'
                          '4. Instructions will appear in the left panel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _onOriginChanged(Waypoint origin) {
    if (_origin == origin) return; // Avoid unnecessary updates

    setState(() {
      _origin = origin;
      _customerPosition = origin;
      _routePlan = null;
      _currentStep = null;
      _distanceToNext = 0.0;
    });
  }

  void _onDestinationChanged(Waypoint destination) {
    if (_destination == destination) return; // Avoid unnecessary updates

    setState(() {
      _destination = destination;
    });
  }

  void _onRouteChanged(RoutePlan? routePlan) {
    setState(() {
      _routePlan = routePlan;
      if (routePlan != null && routePlan.steps.isNotEmpty) {
        _currentStep = routePlan.steps.first;
        _distanceToNext = routePlan.steps.first.distanceMeters;
        _customerPosition = routePlan.steps.first.waypoint;
      } else {
        _currentStep = null;
        _distanceToNext = 0.0;
        _customerPosition = _origin;
      }
    });
  }

  void _toggleSimulation() {
    if (_routePlan == null || _routePlan!.steps.isEmpty) return;

    setState(() {
      _isSimulationRunning = !_isSimulationRunning;
    });

    if (_isSimulationRunning) {
      _startSimulation();
    } else {
      _stopSimulation();
    }
  }

  void _startSimulation() {
    if (_routePlan == null || _routePlan!.steps.isEmpty) return;

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _simulationSpeed).round()),
      _advanceSimulation,
    );
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _advanceSimulation(Timer timer) {
    if (_routePlan == null || _currentStep == null) {
      _stopSimulation();
      return;
    }

    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isSimulationRunning) return;

      setState(() {
        _distanceToNext = (_distanceToNext - 0.5).clamp(0.0, double.infinity);

        if (_distanceToNext <= 0.5) {
          // Advance to next step
          final currentIndex = _getCurrentStepIndex();
          if (currentIndex < (_routePlan!.steps.length - 1)) {
            _currentStep = _routePlan!.steps[currentIndex + 1];
            _distanceToNext = _currentStep!.distanceMeters;
            _customerPosition = _currentStep!.waypoint;
          } else {
            // Reached destination
            _stopSimulation();
            _isSimulationRunning = false;
            _customerPosition = _destination;
          }
        }
      });
    });
  }

  void _onSpeedChanged(double value) {
    if (_simulationSpeed == value) return; // Avoid unnecessary updates

    setState(() {
      _simulationSpeed = value;
    });

    if (_isSimulationRunning) {
      _stopSimulation();
      _startSimulation();
    }
  }

  void _resetSimulation() {
    _stopSimulation();
    setState(() {
      _origin = null;
      _destination = null;
      _routePlan = null;
      _currentStep = null;
      _distanceToNext = 0.0;
      _customerPosition = null;
      _isSimulationRunning = false;
      _simulationSpeed = 1.0;
    });
  }

  int _getCurrentStepIndex() {
    if (_routePlan == null || _currentStep == null) return 0;
    return _routePlan!.steps.indexOf(_currentStep!);
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
