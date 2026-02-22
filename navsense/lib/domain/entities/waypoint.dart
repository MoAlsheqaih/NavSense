class Waypoint {
  final String id;
  final String name;
  final int floor;
  final double x;
  final double y;

  const Waypoint({
    required this.id,
    required this.name,
    required this.floor,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'floor': floor,
      'x': x,
      'y': y,
    };
  }

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      id: json['id'] as String,
      name: json['name'] as String,
      floor: json['floor'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Waypoint && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
