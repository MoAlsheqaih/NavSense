import 'package:navsense/domain/entities/waypoint.dart';

class UwbPosition {
  final String tagId;
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;
  final double accuracy;

  const UwbPosition({
    required this.tagId,
    required this.x,
    required this.y,
    this.z = 0.0,
    required this.timestamp,
    this.accuracy = 0.0,
  });

  Waypoint toWaypoint({String? name, int floor = 0}) {
    return Waypoint(
      id: tagId,
      name: name ?? 'UWB Position',
      floor: floor,
      x: x,
      y: y,
    );
  }

  UwbPosition copyWith({
    String? tagId,
    double? x,
    double? y,
    double? z,
    DateTime? timestamp,
    double? accuracy,
  }) {
    return UwbPosition(
      tagId: tagId ?? this.tagId,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
    );
  }

  @override
  String toString() {
    return 'UwbPosition(tagId: $tagId, x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}, accuracy: ${accuracy.toStringAsFixed(2)}m)';
  }
}
