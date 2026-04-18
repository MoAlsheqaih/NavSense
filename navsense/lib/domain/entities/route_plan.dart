import 'waypoint.dart';

enum TurnDirection { left, right, straight, turnAround, arrived }

class RouteStep {
  final Waypoint waypoint;
  final TurnDirection direction;
  final String instruction; // localization key resolved at presentation layer
  final double distanceMeters;

  const RouteStep({
    required this.waypoint,
    required this.direction,
    required this.instruction,
    required this.distanceMeters,
  });
}

class RoutePlan {
  final String id;
  final Waypoint origin;
  final Waypoint destination;
  final List<RouteStep> steps;
  final Duration estimatedDuration;

  const RoutePlan({
    required this.id,
    required this.origin,
    required this.destination,
    required this.steps,
    required this.estimatedDuration,
  });
}
