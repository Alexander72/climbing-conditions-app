"""HTTP access to OpenWeather One Call API."""

from __future__ import annotations

import logging
from datetime import date

import httpx

logger = logging.getLogger(__name__)

ONE_CALL_DEFAULT = "https://api.openweathermap.org/data/3.0/onecall"


def format_request_error(exc: httpx.RequestError) -> str:
    """httpx sometimes yields an empty str(exc); include type, repr, URL, and chained cause."""
    parts: list[str] = [type(exc).__name__]
    text = str(exc).strip()
    parts.append(text if text else repr(exc))
    req = getattr(exc, "request", None)
    if req is not None:
        try:
            parts.append(f"url={req.url!s}")
        except Exception:
            parts.append("url=(unavailable)")
    cause = exc.__cause__
    if cause is not None:
        ctext = str(cause).strip()
        parts.append(f"cause={type(cause).__name__}: {ctext or repr(cause)}")
    return " | ".join(parts)


def day_summary_url(onecall_base: str) -> str:
    """Derive day_summary URL from configured One Call base, or use the public default."""
    b = (onecall_base or ONE_CALL_DEFAULT).rstrip("/")
    if b.endswith("/onecall"):
        return f"{b}/day_summary"
    return f"{ONE_CALL_DEFAULT}/day_summary"


class OpenWeatherClient:
    """Thin async HTTP calls; no orchestration or business rules."""

    @staticmethod
    async def fetch_forecast(
        client: httpx.AsyncClient,
        base_url: str,
        lat: float,
        lon: float,
        api_key: str,
        units: str,
    ) -> httpx.Response:
        params = {
            "lat": lat,
            "lon": lon,
            "appid": api_key,
            "units": units,
        }
        logger.info("OpenWeather One Call GET base_url=%s lat=%s lon=%s", base_url, lat, lon)
        return await client.get(base_url, params=params)

    @staticmethod
    async def fetch_day_summary(
        client: httpx.AsyncClient,
        url: str,
        lat: float,
        lon: float,
        day: date,
        api_key: str,
        units: str,
    ) -> dict | None:
        params = {
            "lat": lat,
            "lon": lon,
            "date": day.isoformat(),
            "appid": api_key,
            "units": units,
        }
        try:
            logger.info(
                "OpenWeather day_summary GET url=%s lat=%s lon=%s date=%s",
                url,
                lat,
                lon,
                day.isoformat(),
            )
            response = await client.get(url, params=params)
            if response.status_code != 200:
                logger.warning(
                    "day_summary HTTP %s for %s lat=%s lon=%s: %s",
                    response.status_code,
                    day.isoformat(),
                    lat,
                    lon,
                    response.text[:300],
                )
                return None
            return response.json()
        except httpx.RequestError as exc:
            logger.warning(
                "day_summary request error for %s lat=%s lon=%s: %s",
                day.isoformat(),
                lat,
                lon,
                format_request_error(exc),
            )
            return None
