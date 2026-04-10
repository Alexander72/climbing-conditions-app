"""Load local crag JSON by country; resolve which countries overlap a viewport bbox."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

BACKEND_ROOT = Path(__file__).resolve().parent.parent
COUNTRY_BBOXES_PATH = BACKEND_ROOT / "data" / "crag_country_bboxes.json"
CRAGS_DIR = BACKEND_ROOT / "data" / "crags"

_crags_cache: dict[str, list[dict[str, Any]]] = {}
_country_bboxes: dict[str, dict[str, float]] | None = None


def _load_country_bboxes() -> dict[str, dict[str, float]]:
    global _country_bboxes
    if _country_bboxes is not None:
        return _country_bboxes
    if not COUNTRY_BBOXES_PATH.is_file():
        logger.warning("Missing %s — no countries will match", COUNTRY_BBOXES_PATH)
        _country_bboxes = {}
        return _country_bboxes
    with open(COUNTRY_BBOXES_PATH, encoding="utf-8") as f:
        raw = json.load(f)
    _country_bboxes = dict(raw.get("countries") or {})
    return _country_bboxes


def bboxes_overlap(
    a_min_lat: float,
    a_max_lat: float,
    a_min_lng: float,
    a_max_lng: float,
    b_min_lat: float,
    b_max_lat: float,
    b_min_lng: float,
    b_max_lng: float,
) -> bool:
    if a_max_lat < b_min_lat or a_min_lat > b_max_lat:
        return False
    if a_max_lng < b_min_lng or a_min_lng > b_max_lng:
        return False
    return True


def countries_overlapping_bbox(
    min_lat: float,
    max_lat: float,
    min_lng: float,
    max_lng: float,
) -> list[str]:
    countries = _load_country_bboxes()
    out: list[str] = []
    for code, box in countries.items():
        try:
            if bboxes_overlap(
                min_lat,
                max_lat,
                min_lng,
                max_lng,
                float(box["min_lat"]),
                float(box["max_lat"]),
                float(box["min_lng"]),
                float(box["max_lng"]),
            ):
                out.append(code)
        except (KeyError, TypeError, ValueError):
            logger.warning("Invalid bbox entry for country %s: %s", code, box)
    return sorted(out)


def _load_raw_crags(country: str) -> list[dict[str, Any]]:
    if country in _crags_cache:
        return _crags_cache[country]
    path = CRAGS_DIR / f"{country}.json"
    if not path.is_file():
        _crags_cache[country] = []
        return []
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    rows = raw.get("crags")
    if not isinstance(rows, list):
        rows = []
    _crags_cache[country] = rows
    return rows


def point_in_bbox(
    lat: float,
    lng: float,
    min_lat: float,
    max_lat: float,
    min_lng: float,
    max_lng: float,
) -> bool:
    return min_lat <= lat <= max_lat and min_lng <= lng <= max_lng


def list_crags_in_bbox(
    min_lat: float,
    max_lat: float,
    min_lng: float,
    max_lng: float,
    *,
    is_summary_only: bool,
) -> list[dict[str, Any]]:
    """Return crag DTO dicts for the API response."""
    seen: set[str] = set()
    result: list[dict[str, Any]] = []
    for country in countries_overlapping_bbox(min_lat, max_lat, min_lng, max_lng):
        for row in _load_raw_crags(country):
            try:
                lat = float(row["latitude"])
                lng = float(row["longitude"])
            except (KeyError, TypeError, ValueError):
                continue
            if not point_in_bbox(lat, lng, min_lat, max_lat, min_lng, max_lng):
                continue
            param_id = row.get("param_id")
            nid = row.get("id")
            if param_id:
                crag_id = f"{country}:{param_id}"
            elif nid is not None:
                crag_id = f"{country}:{nid}"
            else:
                crag_id = f"{country}:{lat:.6f},{lng:.6f}"
            if crag_id in seen:
                continue
            seen.add(crag_id)
            name = row.get("name")
            if not name or not isinstance(name, str):
                name = "Unknown crag"
            result.append(
                {
                    "id": crag_id,
                    "name": name,
                    "latitude": lat,
                    "longitude": lng,
                    "country": country,
                    "isSummaryOnly": is_summary_only,
                }
            )
    return result
