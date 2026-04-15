"""Weather aggregation: forecast payload plus optional historical day summaries."""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class WeatherServiceError(Exception):
    """Raised when weather cannot be returned; maps to HTTP in the controller."""

    def __init__(self, status_code: int, detail: dict[str, Any] | str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(repr(detail))


def _calendar_dates_oldest_first(
    timezone_name: str | None, timezone_offset: int, n: int
) -> list[date]:
    """Return the last ``n`` local calendar dates for the location, oldest first."""
    if timezone_name:
        try:
            tz = ZoneInfo(timezone_name)
            today_local = datetime.now(tz).date()
            return [today_local - timedelta(days=n - 1 - i) for i in range(n)]
        except Exception:
            logger.warning("Invalid timezone name %r, falling back to offset", timezone_name)

    offset_td = timedelta(seconds=int(timezone_offset))
    tz = timezone(offset_td)
    shifted = datetime.now(timezone.utc).astimezone(tz)
    today_local = shifted.date()
    return [today_local - timedelta(days=n - 1 - i) for i in range(n)]


def _midnight_unix_for_local_date(
    d: date, timezone_name: str | None, timezone_offset: int
) -> int:
    if timezone_name:
        try:
            tz = ZoneInfo(timezone_name)
            local_midnight = datetime(d.year, d.month, d.day, 0, 0, 0, tzinfo=tz)
            return int(local_midnight.timestamp())
        except Exception:
            pass
    offset_td = timedelta(seconds=int(timezone_offset))
    tz = timezone(offset_td)
    local_midnight = datetime(d.year, d.month, d.day, 0, 0, 0, tzinfo=tz)
    return int(local_midnight.timestamp())


def _temperature_from_summary(summary: dict) -> float | None:
    t = summary.get("temperature")
    if not isinstance(t, dict):
        return None
    if "min" in t and "max" in t:
        return (float(t["min"]) + float(t["max"])) / 2.0
    if "afternoon" in t:
        return float(t["afternoon"])
    return None


def build_historical_from_day_summaries(
    dates_oldest_first: list[date],
    summary_by_date: dict[date, dict | None],
    timezone_name: str | None,
    timezone_offset: int,
) -> list[dict]:
    """Same daily rows as the former ``_build_historical_daily`` output, from cached/fetched summaries."""
    historical: list[dict] = []
    for d in dates_oldest_first:
        summary = summary_by_date.get(d)
        if not summary:
            continue
        precip = summary.get("precipitation")
        total = None
        if isinstance(precip, dict) and "total" in precip:
            total = float(precip["total"])
        temp = _temperature_from_summary(summary)
        if temp is None:
            temp = 0.0
        dt_unix = _midnight_unix_for_local_date(d, timezone_name, timezone_offset)
        historical.append({"dt": dt_unix, "temp": temp, "rain": total})
    return historical


async def get_weather_forecast(
    lat: float,
    lon: float,
    *,
    api_key: str | None = None,
    base_url: str | None = None,
) -> dict[str, Any]:
    from services.weather_cell import cell_id_from_lat_lon
    from services.weather_resolution_service import resolve_cell

    cell_id = cell_id_from_lat_lon(lat, lon)
    return await resolve_cell(
        cell_id,
        api_key=api_key,
        base_url=base_url,
    )
