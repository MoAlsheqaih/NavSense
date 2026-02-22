import '../entities/route_plan.dart';
import '../entities/waypoint.dart';

/// Abstract contract for route computation.
/// Implementations are injected via GetIt — do not import concrete classes directly.
abstract class RouteRepository {
  /// Returns a [RoutePlan] from [origin] to [destination].
  /// Throws [RouteException] on failure.
  Future<RoutePlan> computeRoute(Waypoint origin, Waypoint destination);

  /// Returns all known destinations in the building.
  Future<List<Waypoint>> getDestinations();
}

class RouteException implements Exception {
  final String message;
  const RouteException(this.message);

  @override
  String toString() => 'RouteException: $message';
}
