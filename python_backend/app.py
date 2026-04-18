from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Dict, Optional
import uuid
import time

from floor_data import get_all_rooms, get_room_by_name, ROOMS
from route_solver import compute_route
from graph_builder import get_graph_builder

app = FastAPI(
    title="NavSense MIP Routing API",
    description="Room-to-room routing using Single-Commodity Network Flow MIP",
    version="1.0.0"
)


class RouteRequest(BaseModel):
    origin: str = Field(..., description="Origin room name or ID")
    destination: str = Field(..., description="Destination room name or ID")


class RoomInfo(BaseModel):
    id: str
    name: str
    center_x: float
    center_y: float


class RouteResponse(BaseModel):
    route_id: str
    origin: str
    destination: str
    path: List[int]
    distance: float
    solve_time: float
    path_length: int


@app.on_event("startup")
async def startup_event():
    print("Building navigation graph...")
    gb = get_graph_builder()
    print(f"Graph ready: {len(gb.nodes)} nodes, {len(gb.edges)} edges")


@app.get("/")
async def root():
    return {
        "service": "NavSense MIP Routing API",
        "version": "1.0.0",
        "endpoints": ["/api/rooms", "/api/route"]
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "graph_loaded": True}


@app.get("/api/rooms", response_model=List[RoomInfo])
async def list_rooms():
    """List all available rooms."""
    rooms = []
    for room in get_all_rooms():
        center_y, center_x = room.center
        rooms.append(RoomInfo(
            id=room.id,
            name=room.name,
            center_x=center_x,
            center_y=center_y
        ))
    return rooms


@app.post("/api/route", response_model=RouteResponse)
async def compute_route_endpoint(request: RouteRequest):
    """
    Compute optimal route between two rooms using MIP solver.
    
    The MIP uses Single-Commodity Network Flow formulation solved with CBC.
    """
    try:
        result = compute_route(request.origin, request.destination)
        
        return RouteResponse(
            route_id=str(uuid.uuid4()),
            origin=request.origin,
            destination=request.destination,
            path=result['path'],
            distance=result['distance'],
            solve_time=result['solve_time'],
            path_length=result['path_length']
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"MIP solver error: {str(e)}")


@app.get("/api/room/{room_name}", response_model=RoomInfo)
async def get_room(room_name: str):
    """Get details of a specific room."""
    room = get_room_by_name(room_name)
    if room is None:
        raise HTTPException(status_code=404, detail=f"Room not found: {room_name}")
    
    center_y, center_x = room.center
    return RoomInfo(
        id=room.id,
        name=room.name,
        center_x=center_x,
        center_y=center_y
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)