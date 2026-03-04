import os
import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter()

OPENBETA_DEFAULT_HOST = "https://api.openbeta.io"

AREAS_QUERY = """
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
    region: str = Query(default="Belgium", description="Country or region name"),
):
    payload = {
        "query": AREAS_QUERY,
        "variables": {"filter": {"area_name": {"match": region}}},
    }

    openbeta_host = os.getenv("OPENBETA_HOST", OPENBETA_DEFAULT_HOST).rstrip("/")
    openbeta_url = f"{openbeta_host}/graphql"

    async with httpx.AsyncClient() as client:
        response = await client.post(
            openbeta_url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30.0,
        )

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    return response.json()
