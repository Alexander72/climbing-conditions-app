"""Resolve merged One Call + historical weather for a geohash cell (§4)."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import time
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any

import httpx

from clients.openweather_client import (
    ONE_CALL_DEFAULT,
    OpenWeatherClient,
    day_summary_url,
    format_request_error,
)
from repositories.weather_cache_repository import WeatherCacheRepository
from services.weather_cell import openweather_lat_lon_for_cell
from services.weather_service import (
    WeatherServiceError,
    _calendar_dates_oldest_first,
    build_historical_from_day_summaries,
)

logger = logging.getLogger(__name__)

_owm_concurrency = asyncio.Semaphore(4)


def _utc_now_iso_z() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _parse_written_at_utc(iso_z: str) -> datetime:
    if iso_z.endswith("Z"):
        return datetime.fromisoformat(iso_z.replace("Z", "+00:00"))
    return datetime.fromisoformat(iso_z)


def _int_attr(value: Any) -> int:
    if isinstance(value, Decimal):
        return int(value)
    return int(value)


def _forecast_cache_miss(item: dict[str, Any] | None) -> bool:
    if not item:
        return True
    ttl = item.get("ttl")
    if ttl is None:
        return True
    return int(time.time()) >= _int_attr(ttl)


def _day_cache_miss(item: dict[str, Any] | None) -> bool:
    if not item:
        return True
    if "ttl" not in item:
        return True
    return int(time.time()) >= _int_attr(item["ttl"])


def _today_summary_cache_only(item: dict[str, Any]) -> bool:
    """§3.7: today's row is cache-only if ``written_at`` is within the last 3600 s."""
    raw = item.get("written_at")
    if not isinstance(raw, str):
        return False
    written_at = _parse_written_at_utc(raw)
    age_s = (datetime.now(timezone.utc) - written_at).total_seconds()
    return age_s < 3600


def default_weather_cache_repository() -> WeatherCacheRepository:
    """Build cache repository from ``WEATHER_CACHE_TABLE`` and optional DynamoDB endpoint env."""
    table = os.environ.get("WEATHER_CACHE_TABLE")
    if not table:
        raise WeatherServiceError(
            status_code=500,
            detail="WEATHER_CACHE_TABLE is not configured",
        )
    ep = os.environ.get("AWS_ENDPOINT_URL_DYNAMODB")
    return WeatherCacheRepository(
        table,
        endpoint_url=ep if ep else None,
    )


async def resolve_cell(
    cell_id: str,
    *,
    api_key: str | None = None,
    base_url: str | None = None,
    repository: WeatherCacheRepository | None = None,
) -> dict[str, Any]:
    """
    Load or fetch One Call + up to five ``day_summary`` payloads for ``cell_id`` (§4.1).

    Optional ``api_key`` / ``base_url`` override env (used by ``get_weather_forecast``).
    Optional ``repository`` is for tests.
    """
    key = api_key if api_key is not None else os.getenv("OPENWEATHER_API_KEY", "")
    if not key:
        raise WeatherServiceError(
            status_code=500,
            detail="OPENWEATHER_API_KEY is not configured",
        )
    resolved_base = base_url or os.getenv("OPENWEATHER_BASE_URL", ONE_CALL_DEFAULT)

    lat, lon = openweather_lat_lon_for_cell(cell_id)
    repo = repository or default_weather_cache_repository()
    ow = OpenWeatherClient()

    logger.info(
        "Resolving weather cell_id=%s lat=%s lon=%s base=%s",
        cell_id,
        lat,
        lon,
        resolved_base,
    )

    try:
        async with httpx.AsyncClient() as client:
            forecast_item = repo.get_forecast(cell_id)
            forecast_dict: dict[str, Any]
            if _forecast_cache_miss(forecast_item):
                async with _owm_concurrency:
                    response = await ow.fetch_forecast(
                        client, resolved_base, lat, lon, key, "metric"
                    )
                if response.status_code != 200:
                    logger.error(
                        "OpenWeather returned HTTP %s for cell=%s lat=%s lon=%s. Body: %s",
                        response.status_code,
                        cell_id,
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
                forecast_dict = response.json()
                fetched_at = _utc_now_iso_z()
                repo.put_forecast(cell_id, json.dumps(forecast_dict), fetched_at)
            else:
                raw = forecast_item.get("payload")
                if not isinstance(raw, str):
                    raise WeatherServiceError(
                        status_code=500,
                        detail="Invalid forecast cache payload",
                    )
                forecast_dict = json.loads(raw)

            tz_name = forecast_dict.get("timezone")
            if not isinstance(tz_name, str):
                tz_name = None
            tz_offset = int(forecast_dict.get("timezone_offset") or 0)

            dates = _calendar_dates_oldest_first(tz_name, tz_offset, 5)
            today_local = dates[-1]
            summary_url = day_summary_url(resolved_base)
            day_rows = repo.batch_get_day_items(cell_id, dates)
            summary_by_date: dict[date, dict | None] = {}

            for d in dates:
                item = day_rows.get(d)
                if _day_cache_miss(item):
                    async with _owm_concurrency:
                        summ = await ow.fetch_day_summary(
                            client, summary_url, lat, lon, d, key, "metric"
                        )
                    summary_by_date[d] = summ
                    if summ is not None:
                        repo.put_day_summary(
                            cell_id,
                            d,
                            json.dumps(summ),
                            _utc_now_iso_z(),
                            tz_name,
                            tz_offset,
                        )
                    continue

                if d < today_local:
                    summary_by_date[d] = json.loads(item["payload"])
                    continue

                if d == today_local:
                    if item is not None and _today_summary_cache_only(item):
                        summary_by_date[d] = json.loads(item["payload"])
                    else:
                        async with _owm_concurrency:
                            summ = await ow.fetch_day_summary(
                                client, summary_url, lat, lon, d, key, "metric"
                            )
                        summary_by_date[d] = summ
                        if summ is not None:
                            repo.put_day_summary(
                                cell_id,
                                d,
                                json.dumps(summ),
                                _utc_now_iso_z(),
                                tz_name,
                                tz_offset,
                            )
                    continue

            historical = build_historical_from_day_summaries(
                dates, summary_by_date, tz_name, tz_offset
            )
            out = dict(forecast_dict)
            if historical:
                out["historical"] = historical
            logger.info("Resolved weather cell_id=%s", cell_id)
            return out
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
