import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';

/// Abstract routing service interface (SR-ARCH-02).
/// Can be replaced with a real cloud routing backend without changing callers.
abstract class RouteService {
  Future<RoutePlan> computeRoute(Waypoint origin, Waypoint destination);
  Future<List<Waypoint>> getAvailableDestinations();
}
