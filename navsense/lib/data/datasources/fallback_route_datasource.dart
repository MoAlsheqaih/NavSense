import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';
import '../repositories/route_repository_impl.dart';
import 'floor_route_datasource.dart';
import 'mip_route_datasource.dart';

class FallbackRouteDatasource implements RouteDatasourceBase {
  final MipRouteDatasource? _mipDatasource;
  final FloorRouteDatasource _floorDatasource;
  bool _mipAvailable = true;

  FallbackRouteDatasource({
    MipRouteDatasource? mipDatasource,
    required FloorRouteDatasource floorDatasource,
  })  : _mipDatasource = mipDatasource,
        _floorDatasource = floorDatasource;

  @override
  Future<List<Waypoint>> getDestinations() async {
    if (_mipDatasource != null && _mipAvailable) {
      try {
        final destinations = await _mipDatasource!.getDestinations();
        if (destinations.isNotEmpty) {
          return destinations;
        }
      } catch (e) {
        _mipAvailable = false;
      }
    }
    return _floorDatasource.getDestinations();
  }

  @override
  Future<RoutePlan> computeRoute(
    Waypoint origin,
    Waypoint destination,
  ) async {
    if (_mipDatasource != null && _mipAvailable) {
      try {
        final result = await _mipDatasource!.computeRoute(origin, destination);
        if (result.steps.isNotEmpty) {
          return result;
        }
      } catch (e) {
        _mipAvailable = false;
      }
    }
    return _floorDatasource.computeRoute(origin, destination);
  }

  bool get isMipAvailable => _mipAvailable;
}
