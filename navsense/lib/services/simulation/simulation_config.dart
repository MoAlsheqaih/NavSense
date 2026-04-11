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

  /// Ordered list of waypoints the simulated user should walk through.
  /// When provided, the position provider moves toward each waypoint in
  /// sequence instead of wandering randomly.
  final List<Waypoint> waypoints;

  const SimulationConfig({
    this.speed = 1.2,
    this.updateInterval = 0.5,
    this.addNoise = true,
    this.noiseRadius = 0.08,
    required this.destination,
    this.waypoints = const [],
  });

  SimulationConfig copyWith({
    double? speed,
    double? updateInterval,
    bool? addNoise,
    double? noiseRadius,
    Waypoint? destination,
    List<Waypoint>? waypoints,
  }) {
    return SimulationConfig(
      speed: speed ?? this.speed,
      updateInterval: updateInterval ?? this.updateInterval,
      addNoise: addNoise ?? this.addNoise,
      noiseRadius: noiseRadius ?? this.noiseRadius,
      destination: destination ?? this.destination,
      waypoints: waypoints ?? this.waypoints,
    );
  }
}
