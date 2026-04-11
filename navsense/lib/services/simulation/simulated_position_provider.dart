import 'dart:async';
import 'dart:math';

import '../../domain/entities/waypoint.dart';
import 'simulation_config.dart';

class SimulatedPositionProvider {
  final SimulationConfig config;
  final _random = Random();

  StreamController<Waypoint>? _positionController;
  Timer? _updateTimer;
  Waypoint? _currentPosition;
  SimulationState _state = SimulationState.idle;

  static const double _floorWidth = 50.0;
  static const double _floorHeight = 29.0;

  SimulatedPositionProvider({required this.config});

  Stream<Waypoint> get positionStream =>
      _positionController?.stream ?? const Stream.empty();

  Waypoint? get currentPosition => _currentPosition;

  SimulationState get state => _state;

  Future<void> start() async {
    if (_state == SimulationState.running) return;

    _positionController ??= StreamController<Waypoint>.broadcast();

    _currentPosition = _generateRandomPosition();
    _positionController!.add(_currentPosition!);

    _state = SimulationState.running;

    _updateTimer = Timer.periodic(
      Duration(milliseconds: (config.updateInterval * 1000).round()),
      (_) => _updatePosition(),
    );
  }

  void _updatePosition() {
    if (_state != SimulationState.running) return;

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

  Waypoint _generateRandomPosition() {
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
