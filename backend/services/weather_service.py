"""Weather aggregation: forecast payload plus optional historical day summaries."""

from __future__ import annotations

import asyncio
import logging
import os
from datetime import date, datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

import httpx
from dotenv import load_dotenv

from clients.openweather_client import (
    ONE_CALL_DEFAULT,
    OpenWeatherClient,
    day_summary_url,
    format_request_error,
)

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


async def _build_historical_daily(
    client: httpx.AsyncClient,
    summary_url: str,
    lat: float,
    lon: float,
    api_key: str,
    units: str,
    timezone_name: str | None,
    timezone_offset: int,
    days: int = 5,
) -> list[dict]:
    ow = OpenWeatherClient()
    dates = _calendar_dates_oldest_first(timezone_name, timezone_offset, days)
    tasks = [
        ow.fetch_day_summary(client, summary_url, lat, lon, d, api_key, units) for d in dates
    ]
    summaries = await asyncio.gather(*tasks)

    historical: list[dict] = []
    for d, summary in zip(dates, summaries):
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
    key = api_key if api_key is not None else os.getenv("OPENWEATHER_API_KEY", "")
    if not key:
        raise WeatherServiceError(
            status_code=500,
            detail="OPENWEATHER_API_KEY is not configured",
        )

    resolved_base = base_url or os.getenv("OPENWEATHER_BASE_URL", ONE_CALL_DEFAULT)

    logger.info("Fetching weather for lat=%s lon=%s from %s", lat, lon, resolved_base)

    ow = OpenWeatherClient()
    try:
        async with httpx.AsyncClient() as client:
            response = await ow.fetch_forecast(
                client, resolved_base, lat, lon, key, "metric"
            )

            if response.status_code != 200:
                logger.error(
                    "OpenWeather returned HTTP %s for lat=%s lon=%s. Body: %s",
                    response.status_code,
                    lat,
                    lon,
                    response.text,
                )
                raise WeatherServiceError(
                    status_code=response.status_code,
                    detail={
                        "error": "UpstreamError",
                        "message": f"OpenWeather responded with HTTP {response.status_code}",
                        "upstream_body": response.text,
                    },
                )

            payload = response.json()
            tz_name = payload.get("timezone")
            if not isinstance(tz_name, str):
                tz_name = None
            tz_offset = int(payload.get("timezone_offset") or 0)

            summary_url = day_summary_url(resolved_base)
            try:
                historical = await _build_historical_daily(
                    client,
                    summary_url,
                    lat,
                    lon,
                    key,
                    "metric",
                    tz_name,
                    tz_offset,
                    days=5,
                )
                if historical:
                    payload["historical"] = historical
            except Exception:
                logger.exception(
                    "Failed to attach historical day summaries; returning forecast-only payload"
                )

            logger.info("Successfully fetched weather for lat=%s lon=%s", lat, lon)
            return payload
    except WeatherServiceError:
        raise
    except httpx.TimeoutException as exc:
        logger.error("Timeout calling OpenWeather at %s: %s", resolved_base, exc)
        raise WeatherServiceError(
            status_code=504,
            detail={
                "error": "TimeoutException",
                "message": f"Request to OpenWeather timed out: {exc}",
            },
        ) from exc
    except httpx.RequestError as exc:
        detail_text = format_request_error(exc)
        logger.error("Request error calling OpenWeather at %s: %s", resolved_base, detail_text)
        raise WeatherServiceError(
            status_code=502,
            detail={
                "error": type(exc).__name__,
                "message": f"Failed to reach OpenWeather: {detail_text}",
            },
        ) from exc
