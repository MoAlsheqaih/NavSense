import 'package:navsense/domain/entities/waypoint.dart';

class UwbAnchor {
  final String id;
  final String name;
  final double x;
  final double y;
  final double z;
  final double distanceMeters;

  const UwbAnchor({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.z = 0.0,
    this.distanceMeters = 0.0,
  });

  Waypoint toWaypoint({int floor = 0}) {
    return Waypoint(
      id: id,
      name: name,
      floor: floor,
      x: x,
      y: y,
    );
  }

  UwbAnchor copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    double? z,
    double? distanceMeters,
  }) {
    return UwbAnchor(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  @override
  String toString() {
    return 'UwbAnchor(id: $id, name: $name, position: (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)}))';
  }
}
