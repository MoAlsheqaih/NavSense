import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/mock_route_datasource.dart';

class RouteRepositoryImpl implements RouteRepository {
  final MockRouteDatasource _datasource;

  const RouteRepositoryImpl(this._datasource);

  @override
  Future<RoutePlan> computeRoute(Waypoint origin, Waypoint destination) {
    return _datasource.computeRoute(origin, destination);
  }

  @override
  Future<List<Waypoint>> getDestinations() async {
    return _datasource.getDestinations();
  }
}
