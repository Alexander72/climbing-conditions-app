"""Crag catalog domain logic: bbox overlap, grade histograms, listing in viewport."""

from __future__ import annotations

import logging
from typing import Any

from repositories.crag_repository import CragRepository, default_crag_repository

logger = logging.getLogger(__name__)

# Index into each grades.json row: lowercase French sport grade (e.g. 6a, 6b+).
FRENCH_GRADE_INDEX = 4


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
    *,
    repository: CragRepository | None = None,
) -> list[str]:
    repo = repository or default_crag_repository
    countries = repo.get_country_bboxes()
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


def _safe_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _label_for_grade_code(code_str: str, repository: CragRepository) -> str:
    table = repository.get_grades_table()
    row = table.get(code_str)
    if not isinstance(row, list) or len(row) <= FRENCH_GRADE_INDEX:
        return code_str
    label = row[FRENCH_GRADE_INDEX]
    if label is None or not isinstance(label, str) or not label.strip():
        return code_str
    return label.strip()


def grade_histogram_from_route_counts(
    route_counts: Any,
    *,
    repository: CragRepository | None = None,
) -> list[dict[str, Any]]:
    """Merge per-style grade buckets into one histogram (French labels, sorted by internal code)."""
    repo = repository or default_crag_repository
    if not isinstance(route_counts, dict):
        return []
    merged: dict[str, int] = {}
    sort_code: dict[str, int] = {}
    for _style, buckets in route_counts.items():
        if not isinstance(buckets, dict):
            continue
        for code_str, cnt in buckets.items():
            n = _safe_int(cnt)
            if n is None or n <= 0:
                continue
            try:
                code_int = int(code_str)
            except (TypeError, ValueError):
                code_int = 0
            label = _label_for_grade_code(str(code_str), repo)
            merged[label] = merged.get(label, 0) + n
            prev = sort_code.get(label, code_int)
            sort_code[label] = min(prev, code_int)
    if not merged:
        return []
    labels = sorted(merged.keys(), key=lambda lb: sort_code.get(lb, 0))
    return [{"grade": lb, "count": merged[lb]} for lb in labels]


def coarse_grade_histogram_from_row(row: dict[str, Any]) -> list[dict[str, Any]]:
    """Fallback using grade4_count … grade9_count (French class bands)."""
    bins: list[dict[str, Any]] = []
    for band in range(4, 10):
        v = _safe_int(row.get(f"grade{band}_count"))
        if v is not None and v > 0:
            bins.append({"grade": str(band), "count": v})
    return bins


def route_stats_from_row(
    row: dict[str, Any],
    *,
    repository: CragRepository | None = None,
) -> dict[str, Any]:
    """Optional API fields derived from raw catalog row."""
    repo = repository or default_crag_repository
    out: dict[str, Any] = {}
    mapping = (
        ("route_count", "routeCount"),
        ("sport_count", "sportCount"),
        ("trad_n_p_count", "tradNPCount"),
        ("boulder_count", "boulderCount"),
        ("dws_count", "dwsCount"),
    )
    for src, dst in mapping:
        v = _safe_int(row.get(src))
        if v is not None:
            out[dst] = v
    hist = grade_histogram_from_route_counts(row.get("route_counts"), repository=repo)
    if not hist:
        hist = coarse_grade_histogram_from_row(row)
    if hist:
        out["gradeHistogram"] = hist
    return out


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
    repository: CragRepository | None = None,
) -> list[dict[str, Any]]:
    """Return crag DTO dicts for the API response."""
    repo = repository or default_crag_repository
    seen: set[str] = set()
    result: list[dict[str, Any]] = []
    for country in countries_overlapping_bbox(
        min_lat, max_lat, min_lng, max_lng, repository=repo
    ):
        for row in repo.load_crags_for_country(country):
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
            dto: dict[str, Any] = {
                "id": crag_id,
                "name": name,
                "latitude": lat,
                "longitude": lng,
                "country": country,
                "isSummaryOnly": is_summary_only,
            }
            dto.update(route_stats_from_row(row, repository=repo))
            result.append(dto)
    return result
