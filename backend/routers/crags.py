import logging
import os
from typing import Optional
import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter()
logger = logging.getLogger(__name__)

OPENBETA_DEFAULT_HOST = "https://api.openbeta.io"

# Summary query: name + coordinates only (no children), used for zoom 7-9
AREAS_BBOX_SUMMARY_QUERY = """
query GetAreasSummaryByBBox($filter: SearchWithinFilter) {
  cragsWithin(filter: $filter) {
    area_name
    metadata {
      lat
      lng
    }
  }
}
"""

# Full query: name + coordinates + children, used for zoom > 9
AREAS_BBOX_FULL_QUERY = """
query GetAreasFullByBBox($filter: SearchWithinFilter) {
  cragsWithin(filter: $filter) {
    area_name
    metadata {
      lat
      lng
    }
    children {
      area_name
      metadata {
        lat
        lng
      }
    }
  }
}
"""

# Legacy region-based query (fallback when no bbox provided)
AREAS_REGION_QUERY = """
query GetAreasByRegion($filter: Filter) {
  areas(filter: $filter) {
    area_name
    metadata {
      lat
      lng
    }
    children {
      area_name
      metadata {
        lat
        lng
      }
    }
  }
}
"""


@router.get("/crags")
async def get_crags(
    region: str = Query(default="Belgium", description="Country or region name (fallback when no bbox)"),
    min_lat: Optional[float] = Query(default=None, description="Bounding box south latitude"),
    max_lat: Optional[float] = Query(default=None, description="Bounding box north latitude"),
    min_lng: Optional[float] = Query(default=None, description="Bounding box west longitude"),
    max_lng: Optional[float] = Query(default=None, description="Bounding box east longitude"),
    detail_level: str = Query(default="summary", description="'summary' (name+coords) or 'full' (with children)"),
):
    bbox_params = [min_lat, max_lat, min_lng, max_lng]
    use_bbox = all(p is not None for p in bbox_params)

    if use_bbox:
        # OpenBeta cragsWithin bbox: [minLng, minLat, maxLng, maxLat]
        bbox = [min_lng, min_lat, max_lng, max_lat]
        query = AREAS_BBOX_FULL_QUERY if detail_level == "full" else AREAS_BBOX_SUMMARY_QUERY
        variables = {"filter": {"bbox": bbox}}
    else:
        query = AREAS_REGION_QUERY
        variables = {"filter": {"area_name": {"match": region}}}

    payload = {"query": query, "variables": variables}

    openbeta_host = os.getenv("OPENBETA_HOST", OPENBETA_DEFAULT_HOST).rstrip("/")
    openbeta_url = f"{openbeta_host}/graphql"

    logger.info(
        "Fetching crags from %s | bbox=%s detail=%s region=%s",
        openbeta_url, use_bbox, detail_level, region if not use_bbox else None,
    )

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                openbeta_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30.0,
            )
    except httpx.TimeoutException as exc:
        logger.error("Timeout calling OpenBeta at %s: %s", openbeta_url, exc)
        raise HTTPException(
            status_code=504,
            detail={"error": "TimeoutException", "message": f"Request to OpenBeta timed out: {exc}"},
        )
    except httpx.RequestError as exc:
        logger.error("Request error calling OpenBeta at %s: %s", openbeta_url, exc)
        raise HTTPException(
            status_code=502,
            detail={"error": type(exc).__name__, "message": f"Failed to reach OpenBeta: {exc}"},
        )

    if response.status_code != 200:
        logger.error(
            "OpenBeta returned HTTP %s for %s. Body: %s",
            response.status_code, openbeta_url, response.text,
        )
        raise HTTPException(
            status_code=response.status_code,
            detail={
                "error": "UpstreamError",
                "message": f"OpenBeta responded with HTTP {response.status_code}",
                "upstream_body": response.text,
            },
        )

    data = response.json()
    if "errors" in data:
        logger.error("GraphQL errors from OpenBeta: %s", data["errors"])
        raise HTTPException(
            status_code=502,
            detail={"error": "GraphQLError", "message": data["errors"]},
        )

    logger.info("Successfully fetched crags from OpenBeta")
    return data
