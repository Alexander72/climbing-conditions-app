import logging
import os
import httpx
from fastapi import APIRouter, HTTPException, Query
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/weather")
async def get_weather(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
):
    api_key = os.getenv("OPENWEATHER_API_KEY", "")
    if not api_key:
        raise HTTPException(status_code=500, detail="OPENWEATHER_API_KEY is not configured")

    base_url = os.getenv(
        "OPENWEATHER_BASE_URL",
        "https://api.openweathermap.org/data/3.0/onecall",
    )

    params = {
        "lat": lat,
        "lon": lon,
        "appid": api_key,
        "units": "metric",
    }

    logger.info("Fetching weather for lat=%s lon=%s from %s", lat, lon, base_url)

    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(base_url, params=params)
    except httpx.TimeoutException as exc:
        logger.error("Timeout calling OpenWeather at %s: %s", base_url, exc)
        raise HTTPException(
            status_code=504,
            detail={"error": "TimeoutException", "message": f"Request to OpenWeather timed out: {exc}"},
        )
    except httpx.RequestError as exc:
        logger.error("Request error calling OpenWeather at %s: %s", base_url, exc)
        raise HTTPException(
            status_code=502,
            detail={"error": type(exc).__name__, "message": f"Failed to reach OpenWeather: {exc}"},
        )

    if response.status_code != 200:
        logger.error(
            "OpenWeather returned HTTP %s for lat=%s lon=%s. Body: %s",
            response.status_code, lat, lon, response.text,
        )
        raise HTTPException(
            status_code=response.status_code,
            detail={
                "error": "UpstreamError",
                "message": f"OpenWeather responded with HTTP {response.status_code}",
                "upstream_body": response.text,
            },
        )

    logger.info("Successfully fetched weather for lat=%s lon=%s", lat, lon)
    return response.json()
