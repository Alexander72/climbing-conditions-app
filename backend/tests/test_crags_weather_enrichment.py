"""Unit tests for ``crags_weather_enrichment_service`` (cell cap + resolution)."""

from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

from services.crags_weather_enrichment_service import enrich_crags_with_weather
from services.weather_service import WeatherServiceError


def _minimal_merged() -> dict:
    return {
        "current": {
            "temp": 14.0,
            "humidity": 55.0,
            "wind_speed": 3.0,
            "dt": 1700000000,
            "rain": {},
        },
        "historical": [],
    }


def test_enrich_resolves_sequentially_and_attaches_fetched_at() -> None:
    crags = [
        {
            "id": "be:a",
            "name": "A",
            "latitude": 50.54,
            "longitude": 5.26,
            "country": "be",
            "isSummaryOnly": False,
        }
    ]
    repo = MagicMock()
    repo.get_forecast.return_value = {"fetched_at": "2026-02-01T00:00:00Z"}

    call_order: list[str] = []

    async def fake_resolve(cell_id: str, **kwargs):
        call_order.append(cell_id)
        return _minimal_merged()

    async def run():
        with patch(
            "services.crags_weather_enrichment_service.resolve_cell",
            side_effect=fake_resolve,
        ):
            return await enrich_crags_with_weather(crags, repository=repo)

    enriched, cells, partial = asyncio.run(run())

    assert partial is False
    assert len(cells) == 1
    assert len(call_order) == 1
    assert enriched[0]["weatherAsOf"] == "2026-02-01T00:00:00Z"
    assert enriched[0]["conditionScore"] is not None


def test_enrich_omits_cell_on_weather_service_error() -> None:
    crags = [
        {
            "id": "be:a",
            "name": "A",
            "latitude": 50.54,
            "longitude": 5.26,
            "country": "be",
            "isSummaryOnly": False,
        },
    ]
    repo = MagicMock()

    async def boom(cell_id: str, **kwargs):
        raise WeatherServiceError(502, "upstream")

    async def run():
        with patch(
            "services.crags_weather_enrichment_service.resolve_cell",
            side_effect=boom,
        ):
            return await enrich_crags_with_weather(crags, repository=repo)

    enriched, cells, partial = asyncio.run(run())

    assert cells == {}
    assert enriched[0]["conditionScore"] is None
    assert enriched[0]["conditionFactors"] == []


def test_weather_partial_when_more_than_40_distinct_cells() -> None:
    ids_iter = iter([f"{i:05d}" for i in range(41)])

    def fake_cell_id(lat: float, lng: float) -> str:
        return next(ids_iter)

    crags = [
        {
            "id": f"be:{i}",
            "name": "X",
            "latitude": 50.0 + i * 0.01,
            "longitude": 5.0,
            "country": "be",
            "isSummaryOnly": False,
        }
        for i in range(41)
    ]
    repo = MagicMock()
    repo.get_forecast.return_value = {"fetched_at": "2026-01-01T00:00:00Z"}

    async def run():
        with (
            patch(
                "services.crags_weather_enrichment_service.cell_id_from_lat_lon",
                side_effect=fake_cell_id,
            ),
            patch(
                "services.crags_weather_enrichment_service.resolve_cell",
                AsyncMock(return_value=_minimal_merged()),
            ),
        ):
            return await enrich_crags_with_weather(crags, repository=repo)

    enriched, cells, partial = asyncio.run(run())

    assert partial is True
    assert len(cells) == 40
    capped = [e for e in enriched if e["conditionScore"] is None]
    assert len(capped) >= 1
