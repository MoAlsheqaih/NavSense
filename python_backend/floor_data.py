from dataclasses import dataclass
from typing import List, Optional
from enum import Enum


class CellType(Enum):
    WALL = 0
    CORRIDOR = 100
    ROOM = 1
    DOOR = 200


@dataclass
class Room:
    name: str
    bounds: tuple  # (y_min, y_max, x_min, x_max)
    color: str = 'lightblue'

    @property
    def center(self) -> tuple:
        y_min, y_max, x_min, x_max = self.bounds
        return ((y_min + y_max) / 2.0, (x_min + x_max) / 2.0)

    @property
    def id(self) -> str:
        return self.name.lower().replace(' ', '_')


@dataclass
class Corridor:
    name: str
    bounds: tuple  # (y_min, y_max, x_min, x_max)
    color: str = 'lightgray'


@dataclass
class Door:
    bounds: tuple  # (y_min, y_max, x_min, x_max)
    name: str = "Door"


ROOMS = [
    Room('Reception', bounds=(5, 25, 5, 30), color='lightblue'),
    Room('Meeting_Room_1', bounds=(5, 25, 35, 60), color='lightgreen'),
    Room('Meeting_Room_2', bounds=(5, 25, 65, 90), color='lightyellow'),
    Room('Office_1', bounds=(35, 60, 5, 30), color='lightcoral'),
    Room('Office_2', bounds=(35, 60, 35, 60), color='plum'),
    Room('Office_3', bounds=(35, 60, 65, 90), color='peachpuff'),
    Room('Kitchen', bounds=(70, 90, 5, 45), color='khaki'),
    Room('Restroom', bounds=(70, 90, 50, 90), color='lightsteelblue'),
]

CORRIDORS = [
    Corridor('Main_Corridor_V', bounds=(0, 95, 25, 35)),
    Corridor('Main_Corridor_H', bounds=(25, 35, 0, 95)),
    Corridor('Side_Corridor', bounds=(60, 70, 0, 95)),
]

DOORS = [
    Door(bounds=(25, 27, 17, 20), name="Reception"),
    Door(bounds=(25, 27, 47, 50), name="Meeting 1"),
    Door(bounds=(25, 27, 77, 80), name="Meeting 2"),
    Door(bounds=(35, 37, 17, 20), name="Office 1"),
    Door(bounds=(35, 37, 47, 50), name="Office 2"),
    Door(bounds=(35, 37, 77, 80), name="Office 3"),
    Door(bounds=(70, 72, 25, 28), name="Kitchen"),
    Door(bounds=(70, 72, 70, 73), name="Restroom"),
]

GRID_SIZE = (95, 95)


def get_room_by_name(name: str) -> Optional[Room]:
    for room in ROOMS:
        if room.name.lower().replace(' ', '_') == name.lower().replace(' ', '_'):
            return room
        if room.name.lower() == name.lower():
            return room
    return None


def get_all_rooms() -> List[Room]:
    return ROOMS


def get_all_corridors() -> List[Corridor]:
    return CORRIDORS


def get_all_doors() -> List[Door]:
    return DOORS