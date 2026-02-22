import '../../data/datasources/mock_route_datasource.dart';
import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';
import 'route_service.dart';

class MockRouteService implements RouteService {
  final MockRouteDatasource _datasource;

  const MockRouteService(this._datasource);

  @override
  Future<RoutePlan> computeRoute(Waypoint origin, Waypoint destination) {
    return _datasource.computeRoute(origin, destination);
  }

  @override
  Future<List<Waypoint>> getAvailableDestinations() async {
    return _datasource.getDestinations();
  }
}
