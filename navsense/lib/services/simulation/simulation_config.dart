import '../../domain/entities/waypoint.dart';

enum SimulationState {
  idle,
  running,
  paused,
  completed,
  error,
}

class SimulationConfig {
  final double speed;
  final double updateInterval;
  final bool addNoise;
  final double noiseRadius;
  final Waypoint destination;

  const SimulationConfig({
    this.speed = 0.5,
    this.updateInterval = 1.0,
    this.addNoise = true,
    this.noiseRadius = 0.3,
    required this.destination,
  });

  SimulationConfig copyWith({
    double? speed,
    double? updateInterval,
    bool? addNoise,
    double? noiseRadius,
    Waypoint? destination,
  }) {
    return SimulationConfig(
      speed: speed ?? this.speed,
      updateInterval: updateInterval ?? this.updateInterval,
      addNoise: addNoise ?? this.addNoise,
      noiseRadius: noiseRadius ?? this.noiseRadius,
      destination: destination ?? this.destination,
    );
  }
}
