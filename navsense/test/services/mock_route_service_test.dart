import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/data/datasources/floor_route_datasource.dart';
import 'package:navsense/domain/entities/route_plan.dart';
import 'package:navsense/domain/entities/waypoint.dart';
import 'package:navsense/services/routing/mock_route_service.dart';

void main() {
  late MockRouteService service;

  const origin = Waypoint(
      id: 'wp_entrance', name: 'Main Entrance', floor: 0, x: 0, y: 0);
  const destination =
      Waypoint(id: 'wp_lab1', name: 'Lab 101', floor: 1, x: 15, y: 20);

  setUp(() {
    service = MockRouteService(FloorRouteDatasource());
  });

  group('MockRouteService', () {
    test('computeRoute returns a non-null RoutePlan', () async {
      final plan = await service.computeRoute(origin, destination);
      expect(plan, isNotNull);
    });

    test('RoutePlan has correct origin and destination', () async {
      final plan = await service.computeRoute(origin, destination);
      expect(plan.origin.id, origin.id);
      expect(plan.destination.id, destination.id);
    });

    test('RoutePlan has at least one step', () async {
      final plan = await service.computeRoute(origin, destination);
      expect(plan.steps, isNotEmpty);
    });

    test('last step direction is arrived', () async {
      final plan = await service.computeRoute(origin, destination);
      expect(plan.steps.last.direction, TurnDirection.arrived);
    });

    test('all steps have non-negative distance', () async {
      final plan = await service.computeRoute(origin, destination);
      for (final step in plan.steps) {
        expect(step.distanceMeters, greaterThanOrEqualTo(0));
      }
    });

    test('getAvailableDestinations returns non-empty list', () async {
      final dests = await service.getAvailableDestinations();
      expect(dests, isNotEmpty);
    });

    test('estimatedDuration is positive', () async {
      final plan = await service.computeRoute(origin, destination);
      expect(plan.estimatedDuration.inSeconds, greaterThan(0));
    });
  });
}
