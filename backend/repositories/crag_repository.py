"""File-backed crag catalog and related static datasets."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


class CragRepository:
    """Loads country bboxes, per-country crag JSON, and grade labels from disk."""

    def __init__(self, backend_root: Path | None = None) -> None:
        root = backend_root or Path(__file__).resolve().parent.parent
        self._country_bboxes_path = root / "data" / "crag_country_bboxes.json"
        self._crags_dir = root / "data" / "crags"
        self._grades_path = root / "data" / "grades.json"
        self._crags_cache: dict[str, list[dict[str, Any]]] = {}
        self._country_bboxes: dict[str, dict[str, float]] | None = None
        self._grades_table: dict[str, Any] | None = None

    def get_country_bboxes(self) -> dict[str, dict[str, float]]:
        if self._country_bboxes is not None:
            return self._country_bboxes
        if not self._country_bboxes_path.is_file():
            logger.warning("Missing %s — no countries will match", self._country_bboxes_path)
            self._country_bboxes = {}
            return self._country_bboxes
        with open(self._country_bboxes_path, encoding="utf-8") as f:
            raw = json.load(f)
        self._country_bboxes = dict(raw.get("countries") or {})
        return self._country_bboxes

    def get_grades_table(self) -> dict[str, Any]:
        if self._grades_table is not None:
            return self._grades_table
        if not self._grades_path.is_file():
            logger.warning("Missing %s — grade labels fall back to raw codes", self._grades_path)
            self._grades_table = {}
            return self._grades_table
        with open(self._grades_path, encoding="utf-8") as f:
            self._grades_table = json.load(f)
        return self._grades_table

    def load_crags_for_country(self, country: str) -> list[dict[str, Any]]:
        if country in self._crags_cache:
            return self._crags_cache[country]
        path = self._crags_dir / f"{country}.json"
        if not path.is_file():
            self._crags_cache[country] = []
            return []
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)
        rows = raw.get("crags")
        if not isinstance(rows, list):
            rows = []
        self._crags_cache[country] = rows
        return rows


default_crag_repository = CragRepository()
