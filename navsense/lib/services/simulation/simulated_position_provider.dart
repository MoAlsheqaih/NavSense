import 'dart:async';
import 'dart:math';

import '../../domain/entities/waypoint.dart';
import 'simulation_config.dart';

/// Emits simulated user positions.
///
/// When [SimulationConfig.waypoints] is provided the provider moves the
/// simulated user toward each waypoint in sequence, mimicking a real indoor
/// walk along the computed route.  When no waypoints are given it falls back
/// to a random walk (useful for standalone map tests).
class SimulatedPositionProvider {
  final SimulationConfig config;
  final _random = Random();

  StreamController<Waypoint>? _positionController;
  Timer? _updateTimer;
  Waypoint? _currentPosition;
  SimulationState _state = SimulationState.idle;

  /// Index into [config.waypoints] that the simulated user is heading toward.
  int _targetWaypointIndex = 0;

  static const double _floorWidth = 50.0;
  static const double _floorHeight = 29.0;

  /// How close (metres) the simulated user must be to a waypoint before the
  /// provider snaps to it and advances to the next one.
  static const double _arrivalThreshold = 0.5;

  SimulatedPositionProvider({required this.config});

  Stream<Waypoint> get positionStream =>
      _positionController?.stream ?? const Stream.empty();

  Waypoint? get currentPosition => _currentPosition;

  SimulationState get state => _state;

  Future<void> start() async {
    if (_state == SimulationState.running) return;

    _positionController ??= StreamController<Waypoint>.broadcast();
    _targetWaypointIndex = 0;

    // Start near the first waypoint when a route is available.
    if (config.waypoints.isNotEmpty) {
      final first = config.waypoints.first;
      _currentPosition = Waypoint(
        id: 'sim-start',
        name: 'Simulated',
        floor: first.floor,
        x: (first.x + (_random.nextDouble() - 0.5) * 1.0)
            .clamp(0.0, _floorWidth),
        y: (first.y + (_random.nextDouble() - 0.5) * 1.0)
            .clamp(0.0, _floorHeight),
      );
    } else {
      _currentPosition = _randomPosition();
    }

    _positionController!.add(_currentPosition!);
    _state = SimulationState.running;

    _updateTimer = Timer.periodic(
      Duration(milliseconds: (config.updateInterval * 1000).round()),
      (_) => _updatePosition(),
    );
  }

  void _updatePosition() {
    if (_state != SimulationState.running) return;
    if (_currentPosition == null) return;

    if (config.waypoints.isEmpty) {
      _randomWalk();
      return;
    }

    final target = config.waypoints[_targetWaypointIndex];
    final dx = target.x - _currentPosition!.x;
    final dy = target.y - _currentPosition!.y;
    final distanceToTarget = sqrt(dx * dx + dy * dy);

    if (distanceToTarget <= _arrivalThreshold) {
      // Snap to waypoint and advance.
      _currentPosition = Waypoint(
        id: 'sim-wp-$_targetWaypointIndex',
        name: 'Simulated',
        floor: target.floor,
        x: target.x,
        y: target.y,
      );
      _positionController?.add(_currentPosition!);

      if (_targetWaypointIndex < config.waypoints.length - 1) {
        _targetWaypointIndex++;
      } else {
        // All waypoints visited — mark complete.
        _state = SimulationState.completed;
        _updateTimer?.cancel();
        _updateTimer = null;
      }
      return;
    }

    // Move toward target at the configured speed.
    final movement = config.speed * config.updateInterval;
    final ratio = (movement / distanceToTarget).clamp(0.0, 1.0);
    double newX = _currentPosition!.x + dx * ratio;
    double newY = _currentPosition!.y + dy * ratio;

    if (config.addNoise) {
      newX += (_random.nextDouble() - 0.5) * config.noiseRadius * 2;
      newY += (_random.nextDouble() - 0.5) * config.noiseRadius * 2;
    }

    _currentPosition = Waypoint(
      id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Simulated',
      floor: target.floor,
      x: newX.clamp(0.0, _floorWidth),
      y: newY.clamp(0.0, _floorHeight),
    );
    _positionController?.add(_currentPosition!);
  }

  void _randomWalk() {
    final movement = config.speed * config.updateInterval;
    final direction = _random.nextDouble() * 2 * pi;
    double newX = (_currentPosition!.x + cos(direction) * movement)
        .clamp(0.0, _floorWidth);
    double newY = (_currentPosition!.y + sin(direction) * movement)
        .clamp(0.0, _floorHeight);

    if (config.addNoise) {
      newX += (_random.nextDouble() - 0.5) * config.noiseRadius * 2;
      newY += (_random.nextDouble() - 0.5) * config.noiseRadius * 2;
      newX = newX.clamp(0.0, _floorWidth);
      newY = newY.clamp(0.0, _floorHeight);
    }

    _currentPosition = Waypoint(
      id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Simulated',
      floor: 0,
      x: newX,
      y: newY,
    );
    _positionController?.add(_currentPosition!);
  }

  Waypoint _randomPosition() {
    return Waypoint(
      id: 'sim-start',
      name: 'Simulated',
      floor: 0,
      x: _random.nextDouble() * _floorWidth,
      y: _random.nextDouble() * _floorHeight,
    );
  }

  void setPosition(Waypoint position) {
    _currentPosition = position;
    _positionController?.add(position);
  }

  void pause() {
    if (_state != SimulationState.running) return;
    _state = SimulationState.paused;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void resume() {
    if (_state != SimulationState.paused) return;
    _state = SimulationState.running;
    _updateTimer = Timer.periodic(
      Duration(milliseconds: (config.updateInterval * 1000).round()),
      (_) => _updatePosition(),
    );
  }

  Future<void> stop() async {
    _state = SimulationState.idle;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void dispose() {
    stop();
    _positionController?.close();
    _positionController = null;
  }
}
