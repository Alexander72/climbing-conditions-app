"""Map merged One Call + historical JSON into ``WeatherInputs``."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from models.condition.dto import HistoricalDay, WeatherInputs


def weather_inputs_from_merged(merged: dict[str, Any]) -> WeatherInputs:
    """Build calculator inputs from merged One Call JSON (``current`` + optional ``historical``)."""
    current = merged["current"]
    temp = float(current["temp"])
    humidity = float(current["humidity"])
    wind_speed = float(current["wind_speed"])
    rain_1h: float | None = None
    cr = current.get("rain")
    if isinstance(cr, dict) and cr.get("1h") is not None:
        rain_1h = float(cr["1h"])
    current_dt = int(current["dt"])

    historical: list[HistoricalDay] = []
    raw_hist = merged.get("historical")
    if isinstance(raw_hist, list):
        for item in raw_hist:
            if not isinstance(item, dict):
                continue
            dt_u = int(item["dt"])
            r = item.get("rain")
            rain = None if r is None else float(r)
            inst = datetime.fromtimestamp(dt_u, tz=timezone.utc)
            historical.append(
                HistoricalDay(instant=inst, temp=float(item["temp"]), rain=rain)
            )

    forecast: list[Any] = []
    raw_hourly = merged.get("hourly")
    if isinstance(raw_hourly, list):
        forecast = raw_hourly

    return WeatherInputs(
        temperature=temp,
        humidity=humidity,
        precipitation=rain_1h,
        wind_speed=wind_speed,
        current_dt=current_dt,
        historical=historical,
        forecast=forecast,
    )
