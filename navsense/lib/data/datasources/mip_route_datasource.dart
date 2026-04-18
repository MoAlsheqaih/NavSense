import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';

class MipRouteDatasource {
  final String baseUrl;
  final http.Client _client;

  MipRouteDatasource({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConstants.mipBackendUrl,
        _client = client ?? http.Client();

  Future<List<Waypoint>> getDestinations() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/rooms'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to load rooms: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);
      return data
          .map((room) => Waypoint(
                id: room['id'] as String,
                name: room['name'] as String,
                floor: 0,
                x: (room['center_x'] as num).toDouble(),
                y: (room['center_y'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get destinations: $e');
    }
  }

  Future<RoutePlan> computeRoute(
    Waypoint origin,
    Waypoint destination,
  ) async {
    try {
      final originId = _extractRoomId(origin.id);
      final destId = _extractRoomId(destination.id);

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/route'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'origin': originId,
              'destination': destId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception('MIP route failed: ${error['detail']}');
      }

      final data = json.decode(response.body);
      return _convertToRoutePlan(data, origin, destination);
    } catch (e) {
      throw Exception('Failed to compute route: $e');
    }
  }

  String _extractRoomId(String waypointId) {
    if (waypointId.startsWith('room_')) {
      return waypointId.replaceFirst('room_', '');
    }
    for (final roomPrefix in [
      'Reception',
      'Meeting_Room_1',
      'Meeting_Room_2',
      'Office_1',
      'Office_2',
      'Office_3',
      'Kitchen',
      'Restroom',
    ]) {
      if (waypointId.toLowerCase().contains(roomPrefix.toLowerCase())) {
        return roomPrefix;
      }
    }
    return waypointId;
  }

  RoutePlan _convertToRoutePlan(
    Map<String, dynamic> data,
    Waypoint origin,
    Waypoint destination,
  ) {
    final path = data['path'] as List<dynamic>;
    final distance = (data['distance'] as num).toDouble();
    final solveTime = (data['solve_time'] as num).toDouble();
    final pathLength = data['path_length'] as int;

    final metersPerCell = 0.5;
    final totalDistanceMeters = distance * metersPerCell;

    final steps = <RouteStep>[];
    if (path.length > 1) {
      for (int i = 0; i < path.length - 1; i++) {
        steps.add(RouteStep(
          waypoint: Waypoint(
            id: 'step_$i',
            name: 'Node ${path[i]}',
            floor: 0,
            x: path[i].toDouble(),
            y: 0,
          ),
          direction: TurnDirection.straight,
          instruction: 'instruction_go_straight',
          distanceMeters: 1.0,
        ));
      }
    }

    steps.add(RouteStep(
      waypoint: destination,
      direction: TurnDirection.arrived,
      instruction: 'instruction_arrived',
      distanceMeters: 0,
    ));

    return RoutePlan(
      id: data['route_id'] as String,
      origin: origin,
      destination: destination,
      steps: steps,
      estimatedDuration: Duration(
        seconds: (totalDistanceMeters / 1.2).round(),
      ),
    );
  }

  void dispose() {
    _client.close();
  }
}
