import logging
from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from services.crag_catalog import countries_overlapping_bbox, list_crags_in_bbox

router = APIRouter()
logger = logging.getLogger(__name__)


class CragItem(BaseModel):
    id: str
    name: str
    latitude: float = Field(..., description="WGS84 latitude")
    longitude: float = Field(..., description="WGS84 longitude")
    country: str = Field(..., description="ISO 3166-1 alpha-2 country code for the dataset")
    isSummaryOnly: bool


class CragsResponse(BaseModel):
    crags: list[CragItem]


@router.get("/crags", response_model=CragsResponse)
async def get_crags(
    min_lat: float = Query(..., description="Bounding box south latitude"),
    max_lat: float = Query(..., description="Bounding box north latitude"),
    min_lng: float = Query(..., description="Bounding box west longitude"),
    max_lng: float = Query(..., description="Bounding box east longitude"),
    detail_level: Literal["summary", "full"] = Query(
        default="summary",
        description="'summary' → isSummaryOnly true; 'full' → detailed tier",
    ),
):
    if min_lat > max_lat or min_lng > max_lng:
        raise HTTPException(
            status_code=400,
            detail="Invalid bounding box: min_lat must be ≤ max_lat and min_lng must be ≤ max_lng",
        )

    is_summary_only = detail_level != "full"
    countries = countries_overlapping_bbox(min_lat, max_lat, min_lng, max_lng)
    crags = list_crags_in_bbox(
        min_lat,
        max_lat,
        min_lng,
        max_lng,
        is_summary_only=is_summary_only,
    )

    logger.info(
        "Crags bbox | countries=%s count=%s detail=%s",
        countries,
        len(crags),
        detail_level,
    )

    return CragsResponse(crags=[CragItem(**c) for c in crags])
