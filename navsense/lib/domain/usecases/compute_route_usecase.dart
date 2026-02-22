import '../entities/route_plan.dart';
import '../entities/waypoint.dart';
import '../repositories/route_repository.dart';

class ComputeRouteUseCase {
  final RouteRepository _repository;

  const ComputeRouteUseCase(this._repository);

  Future<RoutePlan> call(Waypoint origin, Waypoint destination) {
    return _repository.computeRoute(origin, destination);
  }
}
