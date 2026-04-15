from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from models.condition.enums import Aspect, ClimbingType, RockType


@dataclass(frozen=True)
class HistoricalDay:
    """One row from merged weather ``historical`` (``dt`` unix UTC, daily rain/temp)."""

    instant: datetime
    temp: float
    rain: float | None


@dataclass(frozen=True)
class WeatherInputs:
    temperature: float
    humidity: float
    precipitation: float | None
    wind_speed: float
    current_dt: int
    historical: list[HistoricalDay]
    forecast: list[Any]


@dataclass(frozen=True)
class CragConditionInputs:
    aspect: Aspect = Aspect.unknown
    rock_type: RockType = RockType.limestone
    climbing_types: tuple[ClimbingType, ...] = (ClimbingType.sport,)


@dataclass(frozen=True)
class ConditionResult:
    score: int
    recommendation: str
    factors: list[str]
    last_updated_unix: int
