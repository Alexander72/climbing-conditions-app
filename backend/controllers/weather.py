from fastapi import APIRouter, HTTPException, Query

from services.weather_service import WeatherServiceError, get_weather_forecast

router = APIRouter(tags=["Weather"])


@router.get(
    "/weather",
    summary="Weather at coordinates",
    description="Returns aggregated forecast (and related) weather for the given WGS84 point.",
    responses={502: {"description": "Upstream weather provider error or misconfiguration"}},
)
async def get_weather(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
):
    try:
        return await get_weather_forecast(lat, lon)
    except WeatherServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
