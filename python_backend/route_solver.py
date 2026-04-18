import time
import math
from typing import Dict, List, Tuple, Optional
import pulp

from graph_builder import get_nodes, get_edges, find_closest_node_to_room
from floor_data import ROOMS, Room


class RoomRouteSolver:
    """
    Solve the shortest path between two nodes using a
    Single-Commodity Network Flow MIP with PuLP + CBC.
    """

    def __init__(self):
        self.nodes = get_nodes()
        self.edges = get_edges()
        self.node_ids = sorted(self.nodes.keys())

        self.out_arcs: Dict[int, List[Tuple[int, float]]] = {
            nid: [] for nid in self.node_ids}
        self.in_arcs: Dict[int, List[Tuple[int, float]]] = {
            nid: [] for nid in self.node_ids}

        for edge in self.edges:
            self.out_arcs[edge.i].append((edge.j, edge.distance))
            self.in_arcs[edge.j].append((edge.i, edge.distance))
            self.out_arcs[edge.j].append((edge.i, edge.distance))
            self.in_arcs[edge.i].append((edge.j, edge.distance))

    def solve_between_rooms(self, start_node: int, end_node: int,
                            time_limit: float = 30.0
                            ) -> Dict:
        """
        Return dict with path, total_distance, solve_time.
        """
        t0 = time.time()

        prob = pulp.LpProblem("ShortestPath_NetworkFlow", pulp.LpMinimize)

        x: Dict[Tuple[int, int], pulp.LpVariable] = {}
        for edge in self.edges:
            x[edge.i, edge.j] = pulp.LpVariable(
                f"x_{edge.i}_{edge.j}", cat='Binary')
            x[edge.j, edge.i] = pulp.LpVariable(
                f"x_{edge.j}_{edge.i}", cat='Binary')

        prob += pulp.lpSum(
            edge.distance * x[edge.i, edge.j] +
            edge.distance * x[edge.j, edge.i]
            for edge in self.edges
        ), "Minimize_Path_Distance"

        for v in self.node_ids:
            out_flow = pulp.lpSum(
                x[v, j] for (j, _) in self.out_arcs[v]
                if (v, j) in x
            )
            in_flow = pulp.lpSum(
                x[i, v] for (i, _) in self.in_arcs[v]
                if (i, v) in x
            )

            if v == start_node:
                prob += (out_flow - in_flow == 1), f"flow_source_{v}"
            elif v == end_node:
                prob += (in_flow - out_flow == 1), f"flow_sink_{v}"
            else:
                prob += (out_flow - in_flow == 0), f"flow_conserve_{v}"

        solver = pulp.PULP_CBC_CMD(msg=0,
                                   timeLimit=int(time_limit),
                                   threads=4)
        prob.solve(solver)
        solve_time = time.time() - t0

        successor: Dict[int, int] = {}
        for (i, j), var in x.items():
            if var.varValue is not None and var.varValue > 0.5:
                successor[i] = j

        path: List[int] = [start_node]
        current = start_node
        visited = {start_node}

        for _ in range(len(self.node_ids)):
            nxt = successor.get(current)
            if nxt is None or nxt in visited:
                break
            path.append(nxt)
            visited.add(nxt)
            current = nxt
            if current == end_node:
                break

        total_distance = pulp.value(prob.objective) \
            if prob.objective is not None else float('inf')

        return {
            'path': path,
            'distance': total_distance,
            'solve_time': solve_time,
            'path_length': len(path)
        }

    def solve_room_to_room(self, start_room_name: str, end_room_name: str) -> Dict:
        """Solve route between two rooms by their names."""
        start_node = find_closest_node_to_room(start_room_name)
        end_node = find_closest_node_to_room(end_room_name)

        if start_node is None or end_node is None:
            raise ValueError(f"Could not find nodes for rooms: {start_room_name} -> {end_room_name}")

        result = self.solve_between_rooms(start_node, end_node)
        result['start_room'] = start_room_name
        result['end_room'] = end_room_name
        result['start_node'] = start_node
        result['end_node'] = end_node

        return result


_global_solver: Optional[RoomRouteSolver] = None


def get_solver() -> RoomRouteSolver:
    global _global_solver
    if _global_solver is None:
        _global_solver = RoomRouteSolver()
    return _global_solver


def compute_route(start_room: str, end_room: str) -> Dict:
    """Compute route between two rooms by name."""
    solver = get_solver()
    return solver.solve_room_to_room(start_room, end_room)