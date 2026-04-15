"""T5/T6: GET /api/crags (summary/full) and GET /api/crags/{crag_id:path}."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from main import app
from services.weather_cell import cell_id_from_lat_lon


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_get_crags_summary_only_crags_key(client: TestClient) -> None:
    r = client.get(
        "/api/crags",
        params={
            "min_lat": 50.53,
            "max_lat": 50.55,
            "min_lng": 5.25,
            "max_lng": 5.27,
            "detail_level": "summary",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert set(data.keys()) == {"crags"}
    assert isinstance(data["crags"], list)
    if data["crags"]:
        assert "weatherCells" not in data["crags"][0]


async def _fake_enrich(
    crags: list,
    repository=None,
) -> tuple[list, dict, bool]:
    merged = {
        "current": {
            "temp": 15.0,
            "humidity": 50.0,
            "wind_speed": 2.0,
            "dt": 1700000000,
            "rain": {},
        },
        "historical": [],
    }
    out: list = []
    wcells: dict = {}
    for c in crags:
        cid = cell_id_from_lat_lon(float(c["latitude"]), float(c["longitude"]))
        wcells.setdefault(cid, merged)
        row = dict(c)
        row["weatherCellId"] = cid
        row["conditionScore"] = 85
        row["conditionRecommendation"] = "excellent"
        row["conditionFactors"] = ["No historical weather data available"]
        row["conditionLastUpdated"] = 1700000000
        row["weatherAsOf"] = "2026-01-01T12:00:00Z"
        out.append(row)
    return out, wcells, False


def test_get_crag_by_id_known_returns_200_and_weather_partial_false(client: TestClient) -> None:
    merged = {
        "current": {
            "temp": 15.0,
            "humidity": 50.0,
            "wind_speed": 2.0,
            "dt": 1700000000,
            "rain": {},
        },
        "historical": [],
    }
    with patch(
        "controllers.crags.enrich_crag_detail",
        AsyncMock(
            return_value=(
                {
                    "id": "be:corphalie-huy",
                    "name": "Corphalie",
                    "latitude": 50.54,
                    "longitude": 5.26,
                    "country": "be",
                    "isSummaryOnly": False,
                    "weatherCellId": "u09wv",
                    "conditionScore": 85,
                    "conditionRecommendation": "excellent",
                    "conditionFactors": [],
                    "conditionLastUpdated": 1,
                    "weatherAsOf": "2026-01-01T00:00:00Z",
                },
                {"u09wv": merged},
            )
        ),
    ):
        r = client.get("/api/crags/be:corphalie-huy")
    assert r.status_code == 200
    data = r.json()
    assert data["weatherPartial"] is False
    assert data["crag"]["id"] == "be:corphalie-huy"
    assert "weatherCells" in data
    assert data["crag"]["conditionScore"] == 85


def test_get_crag_by_id_unknown_returns_404(client: TestClient) -> None:
    r = client.get("/api/crags/be:does-not-exist-xyz-123")
    assert r.status_code == 404


def test_get_crags_full_has_weather_and_conditions(client: TestClient) -> None:
    with patch(
        "controllers.crags.enrich_crags_with_weather",
        AsyncMock(side_effect=_fake_enrich),
    ):
        r = client.get(
            "/api/crags",
            params={
                "min_lat": 50.53,
                "max_lat": 50.55,
                "min_lng": 5.25,
                "max_lng": 5.27,
                "detail_level": "full",
            },
        )
    assert r.status_code == 200
    data = r.json()
    assert set(data.keys()) == {"crags", "weatherCells", "weatherPartial"}
    assert data["weatherPartial"] is False
    assert isinstance(data["weatherCells"], dict)
    assert len(data["crags"]) >= 1
    c0 = data["crags"][0]
    assert c0["conditionScore"] == 85
    assert c0["conditionRecommendation"] == "excellent"
    assert "weatherCellId" in c0
    assert c0["weatherCellId"] in data["weatherCells"]
