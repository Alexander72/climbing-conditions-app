"""Resolve weather cells for bbox crags and attach condition fields (detail_level=full)."""

from __future__ import annotations

import logging
from typing import Any

from repositories.weather_cache_repository import WeatherCacheRepository
from services.condition_service import condition_from_merged_with_defaults
from services.weather_cell import cell_id_from_lat_lon
from services.weather_resolution_service import default_weather_cache_repository, resolve_cell
from services.weather_service import WeatherServiceError

logger = logging.getLogger(__name__)

_MAX_RESOLVED_CELLS = 40


async def enrich_crags_with_weather(
    crags: list[dict[str, Any]],
    *,
    repository: WeatherCacheRepository | None = None,
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]], bool]:
    """
    Return enriched crag dicts, ``weatherCells`` map, and ``weatherPartial`` flag.

    Up to ``_MAX_RESOLVED_CELLS`` distinct cells (lexicographic order) are resolved;
    remaining crags are capped (scores null, ``weatherPartial`` true if any capped).
    """
    if not crags:
        return [], {}, False

    repo = repository or default_weather_cache_repository()

    cell_id_per_row: list[str] = []
    for row in crags:
        lat = float(row["latitude"])
        lng = float(row["longitude"])
        cell_id_per_row.append(cell_id_from_lat_lon(lat, lng))

    unique_sorted = sorted(set(cell_id_per_row))
    resolved_list = unique_sorted[:_MAX_RESOLVED_CELLS]
    resolved_set = set(resolved_list)
    weather_partial = any(cid not in resolved_set for cid in cell_id_per_row)

    weather_cells: dict[str, dict[str, Any]] = {}
    fetched_at_by_cell: dict[str, str | None] = {}

    for cell_id in resolved_list:
        try:
            merged = await resolve_cell(cell_id, repository=repo)
        except WeatherServiceError as exc:
            logger.warning("Weather resolution failed for cell_id=%s: %s", cell_id, exc)
            continue
        weather_cells[cell_id] = merged
        item = repo.get_forecast(cell_id)
        fa = item.get("fetched_at") if item else None
        fetched_at_by_cell[cell_id] = fa if isinstance(fa, str) else None

    enriched: list[dict[str, Any]] = []
    for row, cell_id in zip(crags, cell_id_per_row, strict=True):
        out = dict(row)
        out["weatherCellId"] = cell_id
        if cell_id not in resolved_set or cell_id not in weather_cells:
            out["conditionScore"] = None
            out["conditionRecommendation"] = None
            out["conditionFactors"] = []
            out["conditionLastUpdated"] = None
            out["weatherAsOf"] = None
        else:
            merged = weather_cells[cell_id]
            cond = condition_from_merged_with_defaults(merged)
            out["conditionScore"] = cond.score
            out["conditionRecommendation"] = cond.recommendation
            out["conditionFactors"] = cond.factors
            out["conditionLastUpdated"] = cond.last_updated_unix
            out["weatherAsOf"] = fetched_at_by_cell.get(cell_id)
        enriched.append(out)

    return enriched, weather_cells, weather_partial


async def enrich_crag_detail(
    crag: dict[str, Any],
    *,
    repository: WeatherCacheRepository | None = None,
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    """
    Single-crag enrichment: one cell, no 40-cell cap (§6.3).

    Returns enriched crag dict and ``weatherCells`` with zero or one entry.
    ``weatherPartial`` for the HTTP response is always ``false`` (handled in controller).
    """
    repo = repository or default_weather_cache_repository()
    cell_id = cell_id_from_lat_lon(float(crag["latitude"]), float(crag["longitude"]))
    out = dict(crag)
    out["weatherCellId"] = cell_id
    weather_cells: dict[str, dict[str, Any]] = {}

    try:
        merged = await resolve_cell(cell_id, repository=repo)
        weather_cells[cell_id] = merged
        item = repo.get_forecast(cell_id)
        fa = item.get("fetched_at") if item else None
        fetched_at = fa if isinstance(fa, str) else None
        cond = condition_from_merged_with_defaults(merged)
        out["conditionScore"] = cond.score
        out["conditionRecommendation"] = cond.recommendation
        out["conditionFactors"] = cond.factors
        out["conditionLastUpdated"] = cond.last_updated_unix
        out["weatherAsOf"] = fetched_at
    except WeatherServiceError as exc:
        logger.warning("Weather resolution failed for detail cell_id=%s: %s", cell_id, exc)
        out["conditionScore"] = None
        out["conditionRecommendation"] = None
        out["conditionFactors"] = []
        out["conditionLastUpdated"] = None
        out["weatherAsOf"] = None

    return out, weather_cells
