import os
import httpx
from fastapi import APIRouter, HTTPException, Query
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()


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

    async with httpx.AsyncClient() as client:
        response = await client.get(base_url, params=params)

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    return response.json()
