"""Tests for bbox overlap and crag listing."""

import pytest

from services.crag_catalog import (
    bboxes_overlap,
    countries_overlapping_bbox,
    list_crags_in_bbox,
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
