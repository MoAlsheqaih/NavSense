import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/entities/route_plan.dart';
import '../../../../domain/entities/waypoint.dart';
import 'widgets/instructions_panel.dart';
import 'widgets/simulation_map_widget.dart';

// ── State machine ──────────────────────────────────────────────────────────────

enum _SimState { idle, originSet, routeReady, simulating, paused, arrived }

// ── Route segment (for path interpolation) ────────────────────────────────────

class _RouteSegment {
  final Waypoint from;
  final Waypoint to;
  final double length; // metres

  const _RouteSegment({
    required this.from,
    required this.to,
    required this.length,
  });
}

// ── Page ───────────────────────────────────────────────────────────────────────

class SimulationMapPage extends StatefulWidget {
  const SimulationMapPage({super.key});

  @override
  State<SimulationMapPage> createState() => _SimulationMapPageState();
}

class _SimulationMapPageState extends State<SimulationMapPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  _SimState _state = _SimState.idle;
  Waypoint? _origin;
  Waypoint? _destination;
  RoutePlan? _routePlan;

  /// 60-fps live position — only the canvas repaints when this changes.
  final ValueNotifier<Waypoint?> _positionNotifier = ValueNotifier(null);

  // ── Route-following internals ───────────────────────────────────────────────
  List<_RouteSegment> _segments = [];
  double _traveledMeters = 0;
  double _totalRouteMeters = 0;

  Timer? _simTimer;
  Timer? _panelTimer; // 5 fps panel refresh (remaining, ETA, step index)
  DateTime? _lastTick;
  double _simSpeed = 1.0; // m/s

  /// Whether simulation was running before the user started dragging.
  bool _wasSimulating = false;

  /// True while the user's finger is still on the screen dragging.
  bool _isDragActive = false;

  // ── Derived values ─────────────────────────────────────────────────────────

  double get _remainingMeters =>
      (_totalRouteMeters - _traveledMeters).clamp(0.0, double.infinity);

  double get _etaSeconds => _simSpeed > 0 ? _remainingMeters / _simSpeed : 0;

  RouteStep? get _currentStep {
    if (_routePlan == null || _segments.isEmpty) return null;
    double cumulative = 0;
    for (int i = 0; i < _segments.length; i++) {
      cumulative += _segments[i].length;
      if (_traveledMeters <= cumulative + 0.001) {
        return _routePlan!.steps[i];
      }
    }
    return _routePlan!.steps.last;
  }

  int get _currentStepIndex {
    if (_routePlan == null || _segments.isEmpty) return 0;
    double cumulative = 0;
    for (int i = 0; i < _segments.length; i++) {
      cumulative += _segments[i].length;
      if (_traveledMeters <= cumulative + 0.001) return i;
    }
    return (_routePlan!.steps.length - 1).clamp(0, 9999);
  }

  double get _distanceToNextWaypoint {
    if (_segments.isEmpty) return 0;
    double cumulative = 0;
    for (final seg in _segments) {
      cumulative += seg.length;
      if (_traveledMeters <= cumulative + 0.001) {
        return (cumulative - _traveledMeters).clamp(0.0, double.infinity);
      }
    }
    return 0;
  }

  // ── Route segment helpers ──────────────────────────────────────────────────

  void _buildSegments(RoutePlan plan) {
    _segments = [];
    _totalRouteMeters = 0;
    for (int i = 0; i < plan.steps.length - 1; i++) {
      final from = plan.steps[i].waypoint;
      final to = plan.steps[i + 1].waypoint;
      final length = plan.steps[i].distanceMeters;
      if (length > 0) {
        _segments.add(_RouteSegment(from: from, to: to, length: length));
        _totalRouteMeters += length;
      }
    }
  }

  /// Returns the world position of the customer at [meters] along the route.
  Waypoint _positionAtMeters(double meters) {
    if (_segments.isEmpty) {
      return _origin ?? _destination!;
    }
    double remaining = meters.clamp(0.0, _totalRouteMeters);
    for (final seg in _segments) {
      if (remaining <= seg.length + 0.0001) {
        final t =
            seg.length > 0 ? (remaining / seg.length).clamp(0.0, 1.0) : 0.0;
        return Waypoint(
          id: 'sim-pos',
          name: 'Customer',
          floor: seg.from.floor,
          x: seg.from.x + (seg.to.x - seg.from.x) * t,
          y: seg.from.y + (seg.to.y - seg.from.y) * t,
        );
      }
      remaining -= seg.length;
    }
    return _segments.last.to;
  }

  // ── Simulation control ─────────────────────────────────────────────────────

  void _startSimulation() {
    if (_segments.isEmpty) return;
    _lastTick = DateTime.now();
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 16), _onTick);
    // Panel refresh at 5 fps — only redraws the left-side stats.
    _panelTimer?.cancel();
    _panelTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
    setState(() => _state = _SimState.simulating);
  }

  void _pauseSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    _panelTimer?.cancel();
    _panelTimer = null;
    _lastTick = null;
    setState(() => _state = _SimState.paused);
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    _panelTimer?.cancel();
    _panelTimer = null;
    _lastTick = null;
  }

  void _toggleSimulation() {
    if (_state == _SimState.simulating) {
      _pauseSimulation();
    } else if (_state == _SimState.paused ||
        _state == _SimState.routeReady) {
      _startSimulation();
    }
  }

  void _onTick(Timer _) {
    if (!mounted || _state != _SimState.simulating) return;

    final now = DateTime.now();
    final dt =
        now.difference(_lastTick!).inMicroseconds / 1000000.0; // seconds
    _lastTick = now;

    _traveledMeters =
        (_traveledMeters + _simSpeed * dt).clamp(0.0, _totalRouteMeters);

    if (_traveledMeters >= _totalRouteMeters - 0.01) {
      // Arrived at destination
      _stopSimulation();
      _positionNotifier.value = _destination;
      setState(() {
        _traveledMeters = _totalRouteMeters;
        _state = _SimState.arrived;
      });
      _showArrivedDialog();
      return;
    }

    // Update position notifier — only the canvas repaints, not the full page.
    _positionNotifier.value = _positionAtMeters(_traveledMeters);
  }

  // ── Map callbacks ──────────────────────────────────────────────────────────

  /// Called when the user taps to place / update the origin.
  void _onOriginChanged(Waypoint origin) {
    setState(() {
      _origin = origin;
      if (_state == _SimState.idle) _state = _SimState.originSet;
    });
  }

  /// Called when the user taps to place / update the destination.
  void _onDestinationChanged(Waypoint destination) {
    setState(() => _destination = destination);
  }

  /// Called by the map widget after a route is (re)computed.
  void _onRouteChanged(RoutePlan? routePlan) {
    if (!mounted) return;
    setState(() {
      _routePlan = routePlan;
      if (routePlan != null && routePlan.steps.isNotEmpty) {
        _buildSegments(routePlan);
        _traveledMeters = 0;
        _positionNotifier.value = _positionAtMeters(0);

        // Only auto-resume when the drag finger has lifted (_isDragActive == false).
        // During drag the 80ms debounced recomputes will hit this path but we
        // don't want to restart the timer while the user is still dragging.
        if (_wasSimulating && !_isDragActive) {
          _wasSimulating = false;
          Future.microtask(() {
            if (mounted && _state != _SimState.arrived) _startSimulation();
          });
        } else if (!_wasSimulating) {
          _state = _SimState.routeReady;
        }
      } else {
        _segments = [];
        _totalRouteMeters = 0;
        _traveledMeters = 0;
        _positionNotifier.value = null;
        _state = _origin != null ? _SimState.originSet : _SimState.idle;
      }
    });
  }

  /// Called the moment the user starts dragging the origin dot.
  void _onDragStart() {
    _wasSimulating = _state == _SimState.simulating;
    _isDragActive = true;
    if (_state == _SimState.simulating || _state == _SimState.paused) {
      _stopSimulation();
      setState(() => _state = _SimState.paused);
    }
  }

  /// Called when the drag gesture ends — clears the drag guard so the next
  /// route-changed callback can safely auto-resume the simulation.
  void _onDragEnd() {
    _isDragActive = false;
  }

  void _onSpeedChanged(double value) {
    setState(() => _simSpeed = value);
  }

  void _resetSimulation() {
    _stopSimulation();
    _positionNotifier.value = null;
    _isDragActive = false;
    setState(() {
      _state = _SimState.idle;
      _origin = null;
      _destination = null;
      _routePlan = null;
      _segments = [];
      _traveledMeters = 0;
      _totalRouteMeters = 0;
      _wasSimulating = false;
      _simSpeed = 1.0;
    });
  }

  void _showArrivedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Icon(Icons.flag, color: Colors.green, size: 48),
        content: const Text(
          'You have arrived!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSimulation();
            },
            child: const Text('Start Over'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopSimulation();
    _positionNotifier.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  bool get _canToggle =>
      _state == _SimState.routeReady ||
      _state == _SimState.simulating ||
      _state == _SimState.paused;

  bool get _tapEnabled =>
      _state == _SimState.idle || _state == _SimState.originSet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulation Mode'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSimulation,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left panel ───────────────────────────────────────────────────
          SizedBox(
            width: 320,
            child: InstructionsPanel(
              currentStep: _currentStep,
              distanceToNext: _distanceToNextWaypoint,
              currentStepIndex: _currentStepIndex,
              totalSteps: _routePlan?.steps.length ?? 0,
              isSimulationRunning: _state == _SimState.simulating,
              simulationSpeed: _simSpeed,
              onToggleSimulation: _canToggle ? _toggleSimulation : null,
              onResetSimulation: _resetSimulation,
              onSpeedChanged: _onSpeedChanged,
              remainingMeters: _remainingMeters,
              etaSeconds: _etaSeconds,
            ),
          ),

          // ── Right panel (map) ────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Floor Plan',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      _StateChip(state: _state),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLegend(),
                  const SizedBox(height: 12),

                  // Interactive map
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SimulationMapWidget(
                        origin: _origin,
                        liveOrigin: _positionNotifier,
                        destination: _destination,
                        routePlan: _routePlan,
                        onOriginChanged: _onOriginChanged,
                        onDestinationChanged: _onDestinationChanged,
                        onRouteChanged: _onRouteChanged,
                        onDragStart: _onDragStart,
                        onDragEnd: _onDragEnd,
                        tapEnabled: _tapEnabled,
                        isInteractive: _state != _SimState.arrived,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HintBar(state: _state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(Colors.blue, 'Customer'),
        const SizedBox(width: 16),
        _legendDot(Colors.green, 'Destination'),
        const SizedBox(width: 16),
        _legendDot(const Color(0xFFE53935), 'Route'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

// ── State chip ─────────────────────────────────────────────────────────────────

class _StateChip extends StatelessWidget {
  final _SimState state;
  const _StateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _SimState.idle => ('Tap map to set position', Colors.grey),
      _SimState.originSet => ('Tap again for destination', Colors.orange),
      _SimState.routeReady => ('Route ready — press Play', Colors.blue),
      _SimState.simulating => ('Navigating…', Colors.green),
      _SimState.paused => ('Paused — drag or press Play', Colors.orange),
      _SimState.arrived => ('Arrived!', Colors.green),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(state),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Hint bar ───────────────────────────────────────────────────────────────────

class _HintBar extends StatelessWidget {
  final _SimState state;
  const _HintBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      _SimState.idle => '1. Tap on the map to place the customer position (blue dot)',
      _SimState.originSet => '2. Tap again to place the destination (green dot)',
      _SimState.routeReady => '3. Press Play in the left panel to start navigation',
      _SimState.simulating =>
        'Drag the blue dot anywhere to reroute. Navigation resumes automatically.',
      _SimState.paused =>
        'Paused. Drag the blue dot to reroute, or press Play to resume.',
      _SimState.arrived => 'You have arrived! Press Reset to start over.',
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(state),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}
