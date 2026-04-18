import math
from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Set, Optional
import numpy as np
from scipy.spatial import KDTree

from floor_data import ROOMS, CORRIDORS, DOORS, GRID_SIZE, CellType


@dataclass
class Node:
    id: int
    x: float
    y: float
    cell_type: CellType
    room_name: str = None
    is_critical: bool = False

    def distance_to(self, other: 'Node') -> float:
        return math.sqrt((self.x - other.x) ** 2 + (self.y - other.y) ** 2)


@dataclass
class Edge:
    i: int
    j: int
    distance: float


class GraphBuilder:
    """Build sparse graph from floor plan specification."""

    def __init__(self, grid_size: Tuple[int, int] = GRID_SIZE):
        self.grid_size = grid_size
        self.grid = self._create_grid()
        self.nodes: Dict[int, Node] = {}
        self.edges: List[Edge] = []
        self.next_id = 0

    def _create_grid(self) -> np.ndarray:
        h, w = self.grid_size
        grid = np.zeros((h, w), dtype=np.uint8)

        for corridor in CORRIDORS:
            y_min, y_max, x_min, x_max = corridor.bounds
            grid[y_min:y_max, x_min:x_max] = CellType.CORRIDOR.value

        for room in ROOMS:
            y_min, y_max, x_min, x_max = room.bounds
            grid[y_min:y_max, x_min:x_max] = CellType.ROOM.value

        for door in DOORS:
            y_min, y_max, x_min, x_max = door.bounds
            grid[y_min:y_max, x_min:x_max] = CellType.DOOR.value

        return grid

    def _is_walkable(self, y: int, x: int) -> bool:
        if 0 <= y < self.grid_size[0] and 0 <= x < self.grid_size[1]:
            return self.grid[y, x] != CellType.WALL.value
        return False

    def _bresenham_line(self, x0: int, y0: int, x1: int, y1: int) -> List[Tuple[int, int]]:
        points = []
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        x, y = x0, y0
        while True:
            points.append((x, y))
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy
        return points

    def _line_intersects_wall(self, x1: float, y1: float, x2: float, y2: float) -> bool:
        for x, y in self._bresenham_line(int(x1), int(y1), int(x2), int(y2)):
            if not self._is_walkable(y, x):
                return True
        return False

    def _path_crosses_door(self, x1: float, y1: float, x2: float, y2: float) -> bool:
        for x, y in self._bresenham_line(int(x1), int(y1), int(x2), int(y2)):
            if 0 <= y < self.grid_size[0] and 0 <= x < self.grid_size[1]:
                if self.grid[y, x] == CellType.DOOR.value:
                    return True
        return False

    def _can_traverse(self, node_i: Node, node_j: Node) -> Tuple[bool, bool]:
        if self._line_intersects_wall(node_i.x, node_i.y, node_j.x, node_j.y):
            return False, False

        is_through_door = False

        if (node_i.cell_type == CellType.ROOM and
                node_j.cell_type == CellType.ROOM):
            if node_i.room_name != node_j.room_name:
                is_through_door = self._path_crosses_door(
                    node_i.x, node_i.y, node_j.x, node_j.y)
                if not is_through_door:
                    return False, False

        elif ((node_i.cell_type == CellType.ROOM and
               node_j.cell_type == CellType.CORRIDOR) or
              (node_i.cell_type == CellType.CORRIDOR and
               node_j.cell_type == CellType.ROOM)):
            is_through_door = self._path_crosses_door(
                node_i.x, node_i.y, node_j.x, node_j.y)
            if not is_through_door:
                return False, False

        return True, is_through_door

    def _generate_candidates(self, resolution: float) -> List[Node]:
        candidates = []
        step = max(1, int(resolution))

        for y in range(0, self.grid_size[0], step):
            for x in range(0, self.grid_size[1], step):
                if not self._is_walkable(y, x):
                    continue

                cell_val = self.grid[y, x]
                if cell_val == CellType.ROOM.value:
                    cell_type = CellType.ROOM
                    room_name = self._get_room_name(y, x)
                elif cell_val == CellType.DOOR.value:
                    cell_type = CellType.DOOR
                    room_name = None
                else:
                    cell_type = CellType.CORRIDOR
                    room_name = None

                node = Node(id=self.next_id, x=float(x), y=float(y),
                            cell_type=cell_type, room_name=room_name)
                self.next_id += 1
                candidates.append(node)

        return candidates

    def _get_room_name(self, y: float, x: float) -> Optional[str]:
        for room in ROOMS:
            y_min, y_max, x_min, x_max = room.bounds
            if y_min <= y < y_max and x_min <= x < x_max:
                return room.name
        return None

    def _identify_critical(self, candidates: List[Node]) -> set:
        critical = set()
        neighbors = {node.id: [] for node in candidates}

        for node in candidates:
            for other in candidates:
                if node.id != other.id and node.distance_to(other) <= 1.5:
                    neighbors[node.id].append(other)

        for node in candidates:
            neighbor_list = neighbors[node.id]
            if node.cell_type == CellType.DOOR:
                critical.add(node.id)
            elif len(neighbor_list) == 1:
                critical.add(node.id)
            elif len(neighbor_list) >= 3:
                critical.add(node.id)
            elif len(neighbor_list) >= 2:
                angles = [
                    math.atan2(n.y - node.y, n.x - node.x) * 180 / math.pi
                    for n in neighbor_list
                ]
                for i in range(len(angles)):
                    for j in range(i + 1, len(angles)):
                        diff = abs(angles[i] - angles[j])
                        if diff > 180:
                            diff = 360 - diff
                        if diff > 30:
                            critical.add(node.id)

        return critical

    def _prune(self, candidates: List[Node], critical_ids: set) -> Dict[int, Node]:
        pruned: Dict[int, Node] = {}

        for node in candidates:
            if node.id in critical_ids:
                pruned[node.id] = node
                node.is_critical = True

        for node in candidates:
            if node.cell_type == CellType.ROOM:
                pruned[node.id] = node

        has_corridor = any(
            n.cell_type == CellType.CORRIDOR for n in pruned.values()
        )
        if not has_corridor:
            for node in candidates:
                if node.cell_type == CellType.CORRIDOR:
                    pruned[node.id] = node
                    break

        return pruned

    def _build_edges(self, k_neighbors: int = 6, max_radius: float = 5.0):
        nodes_list = list(self.nodes.values())
        positions = np.array([[n.x, n.y] for n in nodes_list])
        tree = KDTree(positions)
        seen_edges: Set[Tuple[int, int]] = set()

        for node in nodes_list:
            distances, indices = tree.query(
                [node.x, node.y],
                k=min(k_neighbors + 1, len(nodes_list)),
                distance_upper_bound=max_radius
            )

            for dist, idx in zip(distances, indices):
                if idx == len(nodes_list):
                    continue
                other = nodes_list[idx]
                if node.id == other.id:
                    continue

                is_feasible, _ = self._can_traverse(node, other)
                if is_feasible:
                    edge_key = (min(node.id, other.id), max(node.id, other.id))
                    if edge_key not in seen_edges:
                        self.edges.append(Edge(i=node.id, j=other.id, distance=dist))
                        seen_edges.add(edge_key)

    def build_graph(self, resolution: float = 1.0,
                    k_neighbors: int = 6,
                    max_radius: float = 5.0) -> Dict[int, Node]:
        print(f"\n[1/4] Generating candidates...")
        candidates = self._generate_candidates(resolution)
        print(f"      Created {len(candidates)} candidates")

        print(f"[2/4] Identifying critical nodes...")
        critical_ids = self._identify_critical(candidates)
        print(f"      Found {len(critical_ids)} critical")

        print(f"[3/4] Pruning...")
        self.nodes = self._prune(candidates, critical_ids)
        print(f"      Retained {len(self.nodes)} nodes")

        print(f"[4/4] Building edges...")
        self._build_edges(k_neighbors, max_radius)
        print(f"      Generated {len(self.edges)} edges\n")

        return self.nodes

    def get_node_coords(self) -> Dict[int, Tuple[float, float]]:
        return {n.id: (n.x, n.y) for n in self.nodes.values()}

    def find_closest_node_to_room_center(self, room_name: str) -> int:
        for room in ROOMS:
            if room.name.lower().replace(' ', '_') == room_name.lower().replace(' ', '_'):
                room = room
                break
        else:
            for room in ROOMS:
                if room.name.lower() == room_name.lower():
                    room = room
                    break
            else:
                raise ValueError(f"Room not found: {room_name}")

        center_y, center_x = room.center

        best_id = None
        best_dist = float('inf')

        for node in self.nodes.values():
            if (node.cell_type == CellType.ROOM and
                    node.room_name == room.name):
                dist = math.hypot(node.x - center_x, node.y - center_y)
                if dist < best_dist:
                    best_dist = dist
                    best_id = node.id

        if best_id is not None:
            return best_id

        for node in self.nodes.values():
            dist = math.hypot(node.x - center_x, node.y - center_y)
            if dist < best_dist:
                best_dist = dist
                best_id = node.id

        return best_id

    def get_nodes(self) -> Dict[int, Node]:
        return self.nodes

    def get_edges(self) -> List[Edge]:
        return self.edges


_global_graph_builder: Optional[GraphBuilder] = None
_global_nodes: Optional[Dict[int, Node]] = None
_global_edges: Optional[List[Edge]] = None


def get_graph_builder() -> GraphBuilder:
    global _global_graph_builder
    if _global_graph_builder is None:
        _global_graph_builder = GraphBuilder()
        _global_graph_builder.build_graph(resolution=1.0, k_neighbors=6, max_radius=5.0)
    return _global_graph_builder


def get_nodes() -> Dict[int, Node]:
    global _global_nodes
    if _global_nodes is None:
        gb = get_graph_builder()
        _global_nodes = gb.get_nodes()
    return _global_nodes


def get_edges() -> List[Edge]:
    global _global_edges
    if _global_edges is None:
        gb = get_graph_builder()
        _global_edges = gb.get_edges()
    return _global_edges


def find_closest_node_to_room(room_name: str) -> int:
    gb = get_graph_builder()
    return gb.find_closest_node_to_room_center(room_name)