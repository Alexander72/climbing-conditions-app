"""T4: golden fixtures for condition scoring (fixed UTC reference instant)."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import pytest

from models.condition.dto import CragConditionInputs
from models.condition.enums import Aspect, ClimbingType, RockType
from services.condition_service import calculate_condition, calculate_condition_forecast

_FIXTURE_DIR = Path(__file__).resolve().parent / "fixtures" / "condition"


def _parse_iso_utc(s: str) -> datetime:
    dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _crag_from_dict(d: dict) -> CragConditionInputs:
    aspects = {a.value for a in Aspect}
    rocks = {r.value for r in RockType}
    aspect = Aspect(d["aspect"]) if d.get("aspect") in aspects else Aspect.unknown
    rock = RockType(d["rock_type"]) if d.get("rock_type") in rocks else RockType.limestone
    ct_raw = d.get("climbing_types") or ["sport"]
    climbing: tuple[ClimbingType, ...] = tuple(
        ClimbingType(x) for x in ct_raw if x in {c.value for c in ClimbingType}
    )
    if not climbing:
        climbing = (ClimbingType.sport,)
    return CragConditionInputs(aspect=aspect, rock_type=rock, climbing_types=climbing)


@pytest.mark.parametrize(
    "fixture_name",
    [
        "golden_no_history.json",
        "golden_rain_today.json",
        "golden_sandstone_north_penalty.json",
    ],
)
def test_condition_golden_fixtures(fixture_name: str) -> None:
    path = _FIXTURE_DIR / fixture_name
    data = json.loads(path.read_text(encoding="utf-8"))
    ref = _parse_iso_utc(data["reference_now_utc"])
    merged = data["merged_weather"]
    exp = data["expected"]
    crag_dict = data.get("crag")
    crag = _crag_from_dict(crag_dict) if crag_dict else CragConditionInputs()

    result = calculate_condition(merged, crag, reference_now=ref)

    assert result.score == exp["conditionScore"]
    assert result.recommendation == exp["conditionRecommendation"]
    assert result.factors == exp["conditionFactors"]
    assert result.last_updated_unix == exp["conditionLastUpdated"]


def test_condition_forecast_returns_up_to_14_days() -> None:
    merged = {
        "current": {
            "dt": 1714305600,
            "temp": 18.0,
            "humidity": 50,
            "wind_speed": 2.0,
            "rain": {},
        },
        "historical": [],
        "daily": [
            {
                "dt": 1714305600 + (86400 * idx),
                "temp": {"day": 18 + idx},
                "humidity": 50,
                "wind_speed": 2.0,
                "rain": 0.0,
            }
            for idx in range(16)
        ],
    }

    out = calculate_condition_forecast(merged)
    assert len(out) == 14
    assert out[0]["date"] == "2024-04-28"
    assert out[-1]["date"] == "2024-05-11"
    assert all("score" in row and "recommendation" in row for row in out)


def test_condition_forecast_pads_to_14_when_daily_is_short() -> None:
    merged = {
        "current": {
            "dt": 1714305600,
            "temp": 18.0,
            "humidity": 50,
            "wind_speed": 2.0,
            "rain": {},
        },
        "historical": [],
        "daily": [
            {
                "dt": 1714305600 + (86400 * idx),
                "temp": {"day": 18 + idx},
                "humidity": 50,
                "wind_speed": 2.0,
                "rain": 2.0 if idx < 7 else 0.0,
            }
            for idx in range(8)
        ],
    }

    out = calculate_condition_forecast(merged)
    assert len(out) == 14
    # Day 8 should still be influenced by rain in recent forecast days.
    assert "No precipitation in the last 5 days" not in out[8]["factors"]
