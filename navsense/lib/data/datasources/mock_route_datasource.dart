import '../../core/constants/app_constants.dart';
import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';

/// Returns a hardcoded mock route. No real server required.
class MockRouteDatasource {
  static final List<Waypoint> _allDestinations = [
    const Waypoint(id: 'wp_entrance', name: 'Main Entrance', floor: 0, x: 0, y: 0),
    const Waypoint(id: 'wp_elevator', name: 'Elevator', floor: 0, x: 10, y: 5),
    const Waypoint(id: 'wp_cafe', name: 'Cafeteria', floor: 0, x: 20, y: 5),
    const Waypoint(id: 'wp_exit', name: 'Emergency Exit', floor: 0, x: 50, y: 0),
  ];

  List<Waypoint> getDestinations() => _allDestinations;

  Future<RoutePlan> computeRoute(
      Waypoint origin, Waypoint destination) async {
    // Simulates ≤3 s route calculation per SRS Spec 10 latency requirement.
    await Future.delayed(AppConstants.mockRouteDelay);

    final steps = <RouteStep>[
      const RouteStep(
        waypoint: Waypoint(
            id: 'wp_step1', name: 'Corridor A', floor: 0, x: 5, y: 0),
        direction: TurnDirection.straight,
        instruction: 'instruction_go_straight',
        distanceMeters: 10,
      ),
      const RouteStep(
        waypoint: Waypoint(
            id: 'wp_step2', name: 'Junction B', floor: 0, x: 5, y: 10),
        direction: TurnDirection.left,
        instruction: 'instruction_turn_left',
        distanceMeters: 8,
      ),
      const RouteStep(
        waypoint: Waypoint(
            id: 'wp_step3', name: 'Hallway C', floor: 0, x: 0, y: 10),
        direction: TurnDirection.right,
        instruction: 'instruction_turn_right',
        distanceMeters: 5,
      ),
      RouteStep(
        waypoint: destination,
        direction: TurnDirection.arrived,
        instruction: 'instruction_arrived',
        distanceMeters: 0,
      ),
    ];

    return RoutePlan(
      id: 'mock-route-${DateTime.now().millisecondsSinceEpoch}',
      origin: origin,
      destination: destination,
      steps: steps,
      estimatedDuration: const Duration(minutes: 3),
    );
  }
}
