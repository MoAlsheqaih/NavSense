import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/route_plan.dart';
import '../../domain/entities/waypoint.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FLOOR PLAN DATA  (ported from University_Floor_Route_Optimizer notebook)
// ─────────────────────────────────────────────────────────────────────────────

const int _kCols = 29; // x: 0-28
const int _kRows = 50; // y: 0-49

/// Scale factor: each grid cell ≈ 0.5 m (building ≈ 14.5 m × 25 m).
const double _kMetersPerCell = 0.5;

class _FloorRoom {
  final String id;
  final String name;
  final int cx, cy; // grid centre (used as Waypoint x/y)
  final List<(int, int)> entrances;

  const _FloorRoom({
    required this.id,
    required this.name,
    required this.cx,
    required this.cy,
    required this.entrances,
  });
}

/// 9 rooms as defined in the notebook.
const List<_FloorRoom> _kRooms = [
  _FloorRoom(
      id: 'room_1',
      name: 'Room 1 (Top-Left)',
      cx: 8,
      cy: 44,
      entrances: [(17, 42), (17, 43), (17, 44)]),
  _FloorRoom(
      id: 'room_2',
      name: 'Room 2 (Top-Right)',
      cx: 24,
      cy: 45,
      entrances: [(23, 41), (24, 41), (25, 41)]),
  _FloorRoom(
      id: 'room_3',
      name: 'Room 3 (Mid-Left)',
      cx: 8,
      cy: 31,
      entrances: [(17, 27), (17, 28), (17, 29)]),
  _FloorRoom(
      id: 'room_4',
      name: 'Room 4 (Mid-Right)',
      cx: 24,
      cy: 31,
      entrances: [(23, 37), (24, 37), (25, 37)]),
  _FloorRoom(
      id: 'room_5',
      name: 'Room 5 (Low-Mid-Left)',
      cx: 8,
      cy: 18,
      entrances: [(17, 18), (17, 19), (17, 20)]),
  _FloorRoom(
      id: 'room_6',
      name: 'Room 6 (Low-Mid-Right)',
      cx: 24,
      cy: 15,
      entrances: [(21, 18), (21, 19), (21, 20)]),
  _FloorRoom(
      id: 'room_7',
      name: 'Room 7 (Lower-Left)',
      cx: 8,
      cy: 12,
      entrances: [(17, 12), (17, 13), (17, 14)]),
  _FloorRoom(
      id: 'room_8',
      name: 'Room 8 (Bot-Left)',
      cx: 8,
      cy: 4,
      entrances: [(17, 4), (17, 5), (17, 6)]),
  _FloorRoom(
      id: 'room_9',
      name: 'Room 9 (Bot-Right)',
      cx: 24,
      cy: 4,
      entrances: [(21, 4), (21, 5), (21, 6)]),
];

Waypoint _roomWaypoint(_FloorRoom room) => Waypoint(
      id: room.id,
      name: room.name,
      floor: 0,
      x: room.cx.toDouble(),
      y: room.cy.toDouble(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// GRID BUILDING  (mirrors build_grid_from_floorplan)
// ─────────────────────────────────────────────────────────────────────────────

enum _CellType { wall, corridor, entrance }

Map<(int, int), _CellType> _buildGrid() {
  final grid = <(int, int), _CellType>{};

  // Default everything to walkable or wall based on room regions:
  // We only need corridor + entrance cells; everything else is wall.
  for (int x = 0; x < _kCols; x++) {
    for (int y = 0; y < _kRows; y++) {
      grid[(x, y)] = _CellType.wall;
    }
  }

  // ── Entrance cells ────────────────────────────────────────────────────────
  for (final room in _kRooms) {
    for (final e in room.entrances) {
      grid[e] = _CellType.entrance;
    }
  }

  // ── Corridors ─────────────────────────────────────────────────────────────
  // Main vertical corridor: x:18-20, full height y:0-49
  for (int x = 18; x <= 20; x++) {
    for (int y = 0; y < _kRows; y++) {
      if (grid[(x, y)] == _CellType.wall) grid[(x, y)] = _CellType.corridor;
    }
  }
  // Horizontal band: y:22-25 (between mid and lower-mid rooms)
  for (int x = 0; x < _kCols; x++) {
    for (int y = 22; y <= 25; y++) {
      if (grid[(x, y)] == _CellType.wall) grid[(x, y)] = _CellType.corridor;
    }
  }
  // Upper horizontal corridor: y:38-40 (right side, connects Room 1 & 2)
  for (int x = 18; x < _kCols; x++) {
    for (int y = 38; y <= 40; y++) {
      if (grid[(x, y)] == _CellType.wall) grid[(x, y)] = _CellType.corridor;
    }
  }

  return grid;
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVIGATION GRAPH  (mirrors build_navigation_graph)
// ─────────────────────────────────────────────────────────────────────────────

class _Graph {
  final List<(int, int)> positions; // node index → (x, y)
  final Map<int, List<(int, double)>> adj; // node index → [(neighbor, cost)]
  final int nRooms; // first nRooms indices are room centres

  const _Graph({
    required this.positions,
    required this.adj,
    required this.nRooms,
  });
}

_Graph _buildGraph(Map<(int, int), _CellType> grid) {
  final walkable = <(int, int)>{};
  for (final entry in grid.entries) {
    if (entry.value == _CellType.corridor ||
        entry.value == _CellType.entrance) {
      walkable.add(entry.key);
    }
  }

  final positions = <(int, int)>[];
  final nodeIndex = <(int, int), int>{};

  // Room centres first
  for (final room in _kRooms) {
    final pos = (room.cx, room.cy);
    nodeIndex[pos] = positions.length;
    positions.add(pos);
  }
  final nRooms = positions.length;

  // Walkable cells
  final sortedWalkable = walkable.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  for (final cell in sortedWalkable) {
    if (!nodeIndex.containsKey(cell)) {
      nodeIndex[cell] = positions.length;
      positions.add(cell);
    }
  }

  final adj = <int, List<(int, double)>>{};

  // Grid adjacency (4-connected, unit cost)
  for (final cell in walkable) {
    final idx = nodeIndex[cell]!;
    for (final d in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      final nb = (cell.$1 + d.$1, cell.$2 + d.$2);
      if (walkable.contains(nb) && nodeIndex.containsKey(nb)) {
        adj.putIfAbsent(idx, () => []).add((nodeIndex[nb]!, 1.0));
      }
    }
  }

  // Room centre → entrance edges
  for (int i = 0; i < _kRooms.length; i++) {
    final room = _kRooms[i];
    for (final ent in room.entrances) {
      if (nodeIndex.containsKey(ent)) {
        final entIdx = nodeIndex[ent]!;
        final dist = sqrt(pow(room.cx - ent.$1, 2) + pow(room.cy - ent.$2, 2));
        adj.putIfAbsent(i, () => []).add((entIdx, dist));
        adj.putIfAbsent(entIdx, () => []).add((i, dist));
      }
    }
  }

  // Deduplicate
  for (final key in adj.keys) {
    final seen = <int>{};
    adj[key] = adj[key]!.where((e) => seen.add(e.$1)).toList();
  }

  return _Graph(positions: positions, adj: adj, nRooms: nRooms);
}

// ─────────────────────────────────────────────────────────────────────────────
// DIJKSTRA  (mirrors Python dijkstra + reconstruct_path)
// Uses O(V²) scan — fast enough for ~1450 nodes, no external package needed.
// ─────────────────────────────────────────────────────────────────────────────

(List<double>, List<int>) _dijkstra(
    Map<int, List<(int, double)>> adj, int source, int nNodes) {
  final dist = List<double>.filled(nNodes, double.infinity);
  final prev = List<int>.filled(nNodes, -1);
  final visited = List<bool>.filled(nNodes, false);
  dist[source] = 0;

  for (int iter = 0; iter < nNodes; iter++) {
    // Pick unvisited node with smallest tentative distance
    int u = -1;
    double minD = double.infinity;
    for (int i = 0; i < nNodes; i++) {
      if (!visited[i] && dist[i] < minD) {
        minD = dist[i];
        u = i;
      }
    }
    if (u == -1) break;
    visited[u] = true;

    for (final neighbor in (adj[u] ?? [])) {
      final v = neighbor.$1;
      final w = neighbor.$2;
      final nd = dist[u] + w;
      if (nd < dist[v]) {
        dist[v] = nd;
        prev[v] = u;
      }
    }
  }
  return (dist, prev);
}

List<int> _reconstructPath(List<int> prev, int target) {
  final path = <int>[];
  int current = target;
  while (current != -1) {
    path.add(current);
    current = prev[current];
  }
  return path.reversed.toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// TURN DETECTION
// ─────────────────────────────────────────────────────────────────────────────

/// Converts a raw grid path (list of node indices) into [RouteStep]s.
/// Direction changes are detected using the cross-product of consecutive
/// movement vectors; straight segments are merged.
List<RouteStep> _pathToSteps(
    List<int> pathNodes, List<(int, int)> positions, _FloorRoom destination) {
  if (pathNodes.length < 2) {
    return [
      RouteStep(
        waypoint: _roomWaypoint(destination),
        direction: TurnDirection.arrived,
        instruction: 'instruction_arrived',
        distanceMeters: 0,
      )
    ];
  }

  final steps = <RouteStep>[];

  int? prevDx, prevDy;
  double segCells = 0;
  int segStartIdx = 0;

  for (int i = 1; i < pathNodes.length; i++) {
    final (x0, y0) = positions[pathNodes[i - 1]];
    final (x1, y1) = positions[pathNodes[i]];
    final dx = x1 - x0;
    final dy = y1 - y0;

    segCells++;

    if (prevDx == null) {
      prevDx = dx;
      prevDy = dy;
      continue;
    }

    // Cross product: prevDir × curDir
    final cross = prevDx * dy - prevDy! * dx;

    final bool dirChanged = (dx != prevDx || dy != prevDy);
    if (dirChanged) {
      TurnDirection turn;
      if (cross > 0) {
        turn = TurnDirection.left;
      } else if (cross < 0) {
        turn = TurnDirection.right;
      } else {
        turn = TurnDirection.straight;
      }

      final (wx, wy) = positions[pathNodes[i - 1]];
      steps.add(RouteStep(
        waypoint: Waypoint(
          id: 'step_${segStartIdx}_$i',
          name: _dirLabel(turn),
          floor: 0,
          x: wx.toDouble(),
          y: wy.toDouble(),
        ),
        direction: turn,
        instruction: _turnInstruction(turn),
        distanceMeters: segCells * _kMetersPerCell,
      ));
      segCells = 0;
      segStartIdx = i;
      prevDx = dx;
      prevDy = dy;
    }
  }

  // Final arrival step
  steps.add(RouteStep(
    waypoint: _roomWaypoint(destination),
    direction: TurnDirection.arrived,
    instruction: 'instruction_arrived',
    distanceMeters: segCells * _kMetersPerCell,
  ));

  return steps;
}

String _dirLabel(TurnDirection d) {
  switch (d) {
    case TurnDirection.left:
      return 'Turn Left';
    case TurnDirection.right:
      return 'Turn Right';
    case TurnDirection.arrived:
      return 'Arrived';
    case TurnDirection.straight:
      return 'Go Straight';
    case TurnDirection.turnAround:
      return 'Turn Around';
  }
}

String _turnInstruction(TurnDirection d) {
  switch (d) {
    case TurnDirection.left:
      return 'instruction_turn_left';
    case TurnDirection.right:
      return 'instruction_turn_right';
    case TurnDirection.arrived:
      return 'instruction_arrived';
    case TurnDirection.straight:
      return 'instruction_go_straight';
    case TurnDirection.turnAround:
      return 'instruction_turn_around';
  }
}

class FloorRouteDatasource {
  late final _Graph _graph;
  late final Map<String, int> _roomNodeIndex;

  FloorRouteDatasource() {
    final grid = _buildGrid();
    _graph = _buildGraph(grid);
    _roomNodeIndex = {
      for (int i = 0; i < _kRooms.length; i++) _kRooms[i].id: i,
    };
  }

  /// Finds the closest graph node to (x, y) by Euclidean distance.
  /// Scans all ~1,450 nodes — fast enough for this grid size.
  /// Never returns null unless the graph is empty.
  int? _findNearestNode(double x, double y) {
    if (_graph.positions.isEmpty) return null;
    int? bestIdx;
    double bestDistSq = double.infinity;
    for (int i = 0; i < _graph.positions.length; i++) {
      final pos = _graph.positions[i];
      final dx = pos.$1 - x;
      final dy = pos.$2 - y;
      final distSq = dx * dx + dy * dy;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Returns all 9 rooms as selectable [Waypoint]s.
  List<Waypoint> getDestinations() => _kRooms.map(_roomWaypoint).toList();

  /// Computes a real Dijkstra route between [origin] and [destination].
  Future<RoutePlan> computeRoute(Waypoint origin, Waypoint destination) async {
    await Future.delayed(AppConstants.mockRouteDelay);

    // Try to find node index - first check room IDs, then check graph cells
    // Round coordinates to find nearest cell
    int? srcIdx = _roomNodeIndex[origin.id];
    int? dstIdx = _roomNodeIndex[destination.id];

    // If not found by ID, look up by x,y coordinates in the graph
    srcIdx ??= _findNearestNode(origin.x, origin.y);
    dstIdx ??= _findNearestNode(destination.x, destination.y);

    if (srcIdx == null || dstIdx == null || srcIdx == dstIdx) {
      return _fallbackPlan(origin, destination);
    }

    final (dist, prev) = _dijkstra(_graph.adj, srcIdx, _graph.positions.length);

    if (dist[dstIdx] == double.infinity) {
      return _fallbackPlan(origin, destination);
    }

    final pathNodes = _reconstructPath(prev, dstIdx);
    // dstIdx may point to a corridor/entrance node (index >= nRooms) when the
    // user taps an arbitrary position. Synthesise a _FloorRoom so _pathToSteps
    // can label the final "arrived" step correctly.
    final destRoom = dstIdx < _kRooms.length
        ? _kRooms[dstIdx]
        : _FloorRoom(
            id: destination.id,
            name: destination.name,
            cx: destination.x.round(),
            cy: destination.y.round(),
            entrances: const [],
          );
    final steps = _pathToSteps(pathNodes, _graph.positions, destRoom);
    final totalDist = dist[dstIdx] * _kMetersPerCell;

    return RoutePlan(
      id: 'route_${DateTime.now().millisecondsSinceEpoch}',
      origin: origin,
      destination: destination,
      steps: steps,
      estimatedDuration:
          Duration(seconds: (totalDist / 1.2).round()), // avg walk 1.2 m/s
    );
  }

  /// Returns a straight-line 2-step plan so the route path always draws,
  /// even when Dijkstra cannot find a connected path.
  RoutePlan _fallbackPlan(Waypoint origin, Waypoint destination) {
    final dist = sqrt(pow(origin.x - destination.x, 2) +
            pow(origin.y - destination.y, 2)) *
        _kMetersPerCell;
    return RoutePlan(
      id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      origin: origin,
      destination: destination,
      steps: [
        RouteStep(
          waypoint: origin,
          direction: TurnDirection.straight,
          instruction: 'instruction_go_straight',
          distanceMeters: dist,
        ),
        RouteStep(
          waypoint: destination,
          direction: TurnDirection.arrived,
          instruction: 'instruction_arrived',
          distanceMeters: 0,
        ),
      ],
      estimatedDuration: Duration(seconds: (dist / 1.2).round()),
    );
  }
}
