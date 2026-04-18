import 'dart:math';
import 'dart:ui';

class PathCorner {
  final Offset position;
  final bool isCorner;
  final bool isDestination;

  const PathCorner({
    required this.position,
    this.isCorner = false,
    this.isDestination = false,
  });

  PathCorner copyWith({
    Offset? position,
    bool? isCorner,
    bool? isDestination,
  }) {
    return PathCorner(
      position: position ?? this.position,
      isCorner: isCorner ?? this.isCorner,
      isDestination: isDestination ?? this.isDestination,
    );
  }
}

class CorridorRouter {
  List<PathCorner> findPath(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    final needsTurn = dx.abs() > 0.3 && dy.abs() > 0.3;

    if (!needsTurn) {
      return [
        PathCorner(position: start),
        PathCorner(position: end, isDestination: true),
      ];
    }

    final corner = _calculateOptimalCorner(start, end);

    return [
      PathCorner(position: start),
      PathCorner(position: corner, isCorner: true),
      PathCorner(position: end, isDestination: true),
    ];
  }

  Offset _calculateOptimalCorner(Offset start, Offset end) {
    final corner1 = Offset(end.dx, start.dy);
    final corner2 = Offset(start.dx, end.dy);

    final dist1 = _dist(start, corner1) + _dist(corner1, end);
    final dist2 = _dist(start, corner2) + _dist(corner2, end);

    return dist1 <= dist2 ? corner1 : corner2;
  }

  double _dist(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return sqrt(dx * dx + dy * dy);
  }
}
