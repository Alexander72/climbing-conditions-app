import logging
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from services.crag_service import countries_overlapping_bbox, find_crag_by_id, list_crags_in_bbox
from services.crags_weather_enrichment_service import enrich_crag_detail, enrich_crags_with_weather

router = APIRouter(tags=["Crags"])
logger = logging.getLogger(__name__)


class GradeHistogramBin(BaseModel):
    grade: str
    count: int


class CragItem(BaseModel):
    id: str
    name: str
    latitude: float = Field(..., description="WGS84 latitude")
    longitude: float = Field(..., description="WGS84 longitude")
    country: str = Field(..., description="ISO 3166-1 alpha-2 country code for the dataset")
    isSummaryOnly: bool
    routeCount: int | None = None
    sportCount: int | None = None
    tradNPCount: int | None = None
    boulderCount: int | None = None
    dwsCount: int | None = None
    gradeHistogram: list[GradeHistogramBin] | None = None


class CragFullItem(CragItem):
    weatherCellId: str
    conditionScore: int | None = None
    conditionRecommendation: str | None = None
    conditionFactors: list[str] = Field(default_factory=list)
    conditionLastUpdated: int | None = None
    weatherAsOf: str | None = None


class CragsSummaryResponse(BaseModel):
    crags: list[CragItem]


class CragsFullResponse(BaseModel):
    crags: list[CragFullItem]
    weatherCells: dict[str, dict[str, Any]]
    weatherPartial: bool


class CragDetailResponse(BaseModel):
    crag: CragFullItem
    weatherCells: dict[str, dict[str, Any]]
    weatherPartial: bool = False


@router.get(
    "/crags/{crag_id:path}",
    response_model=CragDetailResponse,
    summary="Single crag by id",
    description="Looks up one crag by catalog id (e.g. `{country}:{param_id}`). Path may contain `:`.",
    responses={404: {"description": "Unknown crag id"}},
)
async def get_crag_by_id(crag_id: str) -> CragDetailResponse:
    crag = find_crag_by_id(crag_id)
    if crag is None:
        raise HTTPException(status_code=404, detail="Crag not found")
    enriched, weather_cells = await enrich_crag_detail(crag)
    return CragDetailResponse(
        crag=CragFullItem(**enriched),
        weatherCells=weather_cells,
        weatherPartial=False,
    )


@router.get(
    "/crags",
    response_model=CragsSummaryResponse | CragsFullResponse,
    summary="Crags in bounding box",
    description="Lists crags whose coordinates fall inside the given WGS84 bounding box.",
    responses={400: {"description": "Invalid bounding box"}},
)
async def get_crags(
    min_lat: float = Query(..., description="Bounding box south latitude"),
    max_lat: float = Query(..., description="Bounding box north latitude"),
    min_lng: float = Query(..., description="Bounding box west longitude"),
    max_lng: float = Query(..., description="Bounding box east longitude"),
    detail_level: Literal["summary", "full"] = Query(
        default="summary",
        description="'summary' → isSummaryOnly true; 'full' → detailed tier with weather",
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

    if detail_level == "full":
        enriched, weather_cells, weather_partial = await enrich_crags_with_weather(crags)
        return CragsFullResponse(
            crags=[CragFullItem(**c) for c in enriched],
            weatherCells=weather_cells,
            weatherPartial=weather_partial,
        )

    return CragsSummaryResponse(crags=[CragItem(**c) for c in crags])
