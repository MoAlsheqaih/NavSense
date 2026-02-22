import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';

class RouteStepModel {
  final Map<String, dynamic> waypointJson;
  final String direction;
  final String instruction;
  final double distanceMeters;

  const RouteStepModel({
    required this.waypointJson,
    required this.direction,
    required this.instruction,
    required this.distanceMeters,
  });

  RouteStep toDomain() {
    return RouteStep(
      waypoint: Waypoint.fromJson(waypointJson),
      direction: _parseDirection(direction),
      instruction: instruction,
      distanceMeters: distanceMeters,
    );
  }

  static TurnDirection _parseDirection(String value) {
    switch (value) {
      case 'left':
        return TurnDirection.left;
      case 'right':
        return TurnDirection.right;
      case 'arrived':
        return TurnDirection.arrived;
      default:
        return TurnDirection.straight;
    }
  }
}
