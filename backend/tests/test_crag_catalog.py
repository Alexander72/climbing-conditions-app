"""Tests for bbox overlap and crag listing."""

import pytest

from services.crag_catalog import (
    bboxes_overlap,
    coarse_grade_histogram_from_row,
    countries_overlapping_bbox,
    grade_histogram_from_route_counts,
    list_crags_in_bbox,
    route_stats_from_row,
)


def test_bboxes_overlap_disjoint_and_intersecting():
    assert bboxes_overlap(0, 1, 0, 1, 2, 3, 0, 1) is False
    assert bboxes_overlap(0, 1, 0, 1, 0.5, 1.5, 0.5, 1.5) is True


def test_countries_overlapping_belgium_viewport():
    codes = countries_overlapping_bbox(50.0, 51.0, 4.0, 5.0)
    assert "be" in codes


def test_list_crags_small_bbox_has_results():
    # Corphalie (Huy) area from bundled BE data
    crags = list_crags_in_bbox(50.53, 50.55, 5.25, 5.27, is_summary_only=True)
    assert len(crags) >= 1
    assert all("id" in c and "country" in c for c in crags)


def test_list_crags_empty_when_no_country_file_overlap():
    # Pacific — no configured country bbox should overlap (unless extended)
    crags = list_crags_in_bbox(-5.0, -4.0, -150.0, -149.0, is_summary_only=True)
    assert crags == []


def test_grade_histogram_merges_styles_and_sorts_by_code():
    rc = {
        "Sport": {"100": 2, "400": 5},
        "Traditional": {"100": 1},
    }
    hist = grade_histogram_from_route_counts(rc)
    assert len(hist) == 2
    assert hist[0]["grade"] == "3"
    assert hist[0]["count"] == 3
    assert hist[1]["grade"] == "6a"
    assert hist[1]["count"] == 5


def test_coarse_histogram_skips_zero_bands():
    row = {"grade4_count": 2, "grade6_count": 1}
    hist = coarse_grade_histogram_from_row(row)
    assert hist == [{"grade": "4", "count": 2}, {"grade": "6", "count": 1}]


def test_route_stats_prefers_route_counts_over_coarse():
    row = {
        "route_count": 10,
        "sport_count": 7,
        "trad_n_p_count": 3,
        "boulder_count": 0,
        "dws_count": 0,
        "grade4_count": 99,
        "route_counts": {"Sport": {"400": 4}},
    }
    stats = route_stats_from_row(row)
    assert stats["routeCount"] == 10
    assert stats["sportCount"] == 7
    assert stats["tradNPCount"] == 3
    assert stats["boulderCount"] == 0
    assert stats["dwsCount"] == 0
    assert stats["gradeHistogram"] == [{"grade": "6a", "count": 4}]


def test_list_crags_corphalie_bbox_has_route_stats():
    crags = list_crags_in_bbox(50.53, 50.55, 5.25, 5.27, is_summary_only=True)
    assert len(crags) >= 1
    c0 = next(c for c in crags if "corphalie" in c["id"])
    assert c0.get("routeCount", 0) >= 1
    assert c0.get("gradeHistogram")
    assert isinstance(c0["gradeHistogram"], list)
