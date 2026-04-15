from __future__ import annotations

from enum import Enum


class Aspect(str, Enum):
    north = "north"
    northeast = "northeast"
    east = "east"
    southeast = "southeast"
    south = "south"
    southwest = "southwest"
    west = "west"
    northwest = "northwest"
    unknown = "unknown"

    @property
    def display_name(self) -> str:
        return _ASPECT_DISPLAY[self]


_ASPECT_DISPLAY: dict[Aspect, str] = {
    Aspect.north: "North",
    Aspect.northeast: "Northeast",
    Aspect.east: "East",
    Aspect.southeast: "Southeast",
    Aspect.south: "South",
    Aspect.southwest: "Southwest",
    Aspect.west: "West",
    Aspect.northwest: "Northwest",
    Aspect.unknown: "Unknown",
}


class RockType(str, Enum):
    sandstone = "sandstone"
    granite = "granite"
    limestone = "limestone"

    @property
    def display_name(self) -> str:
        return _ROCK_DISPLAY[self]


_ROCK_DISPLAY: dict[RockType, str] = {
    RockType.sandstone: "Sandstone",
    RockType.granite: "Granite",
    RockType.limestone: "Limestone",
}


class ClimbingType(str, Enum):
    sport = "sport"
    trad = "trad"
    boulder = "boulder"


class ConditionRecommendation(str, Enum):
    excellent = "excellent"
    good = "good"
    fair = "fair"
    poor = "poor"
    dangerous = "dangerous"
