"""Server-side climbing condition scores from merged weather payloads."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any, Sequence

from models.condition.constants import MAX_WIND_SPEED_MS, MIN_TEMPERATURE_C
from models.condition.dto import CragConditionInputs, ConditionResult, HistoricalDay, WeatherInputs
from models.condition.enums import Aspect, ClimbingType, ConditionRecommendation, RockType
from models.condition.merged_weather import weather_inputs_from_merged


def _days_since(now: datetime, past: datetime) -> int:
    now_u = now.astimezone(timezone.utc)
    p_u = past.astimezone(timezone.utc)
    return (now_u - p_u).days


def _recent_precipitation_score(
    historical: list[HistoricalDay], now: datetime, factors: list[str]
) -> int:
    if not historical:
        factors.append("No historical weather data available")
        return 15

    recent_days = [h for h in historical if _days_since(now, h.instant) <= 5]
    if not recent_days:
        factors.append("No recent precipitation data")
        return 15

    days_with_rain = sum(
        1 for d in recent_days if d.rain is not None and d.rain > 0
    )
    if days_with_rain == 0:
        factors.append("No precipitation in the last 5 days")
        return 30

    most_recent_rain = [d for d in recent_days if d.rain is not None and d.rain > 0]
    if most_recent_rain:
        most_recent_rain.sort(key=lambda d: d.instant, reverse=True)
        days_since_rain = _days_since(now, most_recent_rain[0].instant)
        if days_since_rain == 0:
            factors.append("Rain today - conditions poor")
            return 0
        if days_since_rain == 1:
            factors.append("Rain yesterday - rock may still be wet")
            return 5
        if days_since_rain == 2:
            factors.append("Rain 2 days ago - drying conditions")
            return 10
        if days_since_rain == 3:
            factors.append("Rain 3 days ago - mostly dry")
            return 20
        factors.append(f"Rain {days_since_rain} days ago - should be dry")
        return 25

    return 15


def _current_weather_score(weather: WeatherInputs, factors: list[str]) -> int:
    score = 25
    if weather.precipitation is not None and weather.precipitation > 0:
        factors.append("Currently raining - not recommended")
        return 0

    t = weather.temperature
    if t < MIN_TEMPERATURE_C:
        factors.append(f"Temperature too cold ({t:.1f}°C)")
        score -= 10
    elif t > 35:
        factors.append(f"Temperature very hot ({t:.1f}°C)")
        score -= 5
    else:
        factors.append(f"Temperature good ({t:.1f}°C)")

    w = weather.wind_speed
    if w > MAX_WIND_SPEED_MS:
        factors.append(f"Wind speed too high ({w:.1f} m/s)")
        score -= 10
    elif w > 20:
        factors.append(f"Moderate wind ({w:.1f} m/s)")
        score -= 5

    return max(0, min(25, score))


def _has_recent_rain(historical: list[HistoricalDay], now: datetime, *, days: int) -> bool:
    return any(
        _days_since(now, h.instant) <= days and h.rain is not None and h.rain > 0
        for h in historical
    )


def _aspect_score(aspect: Aspect, historical: list[HistoricalDay], now: datetime, factors: list[str]) -> int:
    if not _has_recent_rain(historical, now, days=3):
        factors.append(f"{aspect.display_name}-facing: No recent rain concerns")
        return 20

    if aspect in (Aspect.north, Aspect.northeast, Aspect.northwest):
        factors.append(f"{aspect.display_name}-facing: Slower drying, more shade")
        return 10
    if aspect in (Aspect.south, Aspect.southeast, Aspect.southwest):
        factors.append(f"{aspect.display_name}-facing: Faster drying, more sun")
        return 18
    if aspect in (Aspect.east, Aspect.west):
        factors.append(f"{aspect.display_name}-facing: Moderate drying")
        return 15
    factors.append("Aspect unknown: Assuming moderate conditions")
    return 12


def _rock_type_score(
    rock_type: RockType,
    historical: list[HistoricalDay],
    current_precipitation: float | None,
    now: datetime,
    factors: list[str],
) -> int:
    has_recent = _has_recent_rain(historical, now, days=3) or (
        current_precipitation is not None and current_precipitation > 0
    )
    if not has_recent:
        factors.append(f"{rock_type.display_name}: No moisture concerns")
        return 15

    if rock_type is RockType.sandstone:
        factors.append(f"{rock_type.display_name}: Very sensitive to moisture, brittle when wet")
        return 0
    if rock_type is RockType.granite:
        factors.append(f"{rock_type.display_name}: More resistant but still affected by moisture")
        return 8
    factors.append(f"{rock_type.display_name}: Moderate sensitivity to moisture")
    return 10


def _climbing_style_score(
    climbing_types: Sequence[ClimbingType], current_score: int, factors: list[str]
) -> int:
    if ClimbingType.sport in climbing_types:
        factors.append("Sport climbing: More forgiving conditions")
        return 10
    if ClimbingType.trad in climbing_types:
        factors.append("Trad climbing: Requires better conditions")
        return 7
    if ClimbingType.boulder in climbing_types:
        factors.append("Bouldering: Can be sensitive to conditions")
        return 8
    return 10


def _apply_special_penalties(
    crag: CragConditionInputs,
    weather: WeatherInputs,
    score: int,
    now: datetime,
    factors: list[str],
) -> int:
    has_recent = _has_recent_rain(weather.historical, now, days=3) or (
        weather.precipitation is not None and weather.precipitation > 0
    )
    if (
        crag.rock_type is RockType.sandstone
        and crag.aspect in (Aspect.north, Aspect.northeast, Aspect.northwest)
        and has_recent
    ):
        score -= 40
        factors.append(
            "CRITICAL: Sandstone + North-facing + Recent rain = Very dangerous conditions"
        )
    return score


def _recommendation_for_score(score: int) -> ConditionRecommendation:
    if score >= 80:
        return ConditionRecommendation.excellent
    if score >= 60:
        return ConditionRecommendation.good
    if score >= 40:
        return ConditionRecommendation.fair
    if score >= 20:
        return ConditionRecommendation.poor
    return ConditionRecommendation.dangerous


def _to_utc_datetime(unix_ts: int) -> datetime:
    return datetime.fromtimestamp(unix_ts, tz=timezone.utc)


def _daily_entries(merged_weather: dict[str, Any]) -> list[dict[str, Any]]:
    raw = merged_weather.get("daily")
    if not isinstance(raw, list):
        return []
    return [item for item in raw if isinstance(item, dict) and item.get("dt") is not None]


def _matching_daily_entry(merged_weather: dict[str, Any], target_date: date) -> dict[str, Any] | None:
    for item in _daily_entries(merged_weather):
        dt = _to_utc_datetime(int(item["dt"]))
        if dt.date() == target_date:
            return item
    return None


def _daily_temperature(item: dict[str, Any], fallback: float) -> float:
    temp = item.get("temp")
    if isinstance(temp, dict):
        day = temp.get("day")
        if day is not None:
            return float(day)
        tmin = temp.get("min")
        tmax = temp.get("max")
        if tmin is not None and tmax is not None:
            return (float(tmin) + float(tmax)) / 2.0
    if isinstance(temp, (int, float)):
        return float(temp)
    return fallback


def _daily_precipitation(item: dict[str, Any], fallback: float | None) -> float | None:
    if item.get("rain") is not None:
        return float(item["rain"])
    if item.get("snow") is not None:
        return float(item["snow"])
    if item.get("pop") is not None and float(item["pop"]) >= 0.6:
        return 0.1
    return fallback


def _historical_with_forecast(
    base_historical: list[HistoricalDay],
    merged_weather: dict[str, Any],
    target_now: datetime,
) -> list[HistoricalDay]:
    out = list(base_historical)
    current = merged_weather.get("current")
    if not isinstance(current, dict) or current.get("dt") is None:
        return out
    base_now = _to_utc_datetime(int(current["dt"]))
    if target_now <= base_now:
        return out

    for item in _daily_entries(merged_weather):
        entry_dt = _to_utc_datetime(int(item["dt"]))
        if entry_dt <= base_now or entry_dt > target_now:
            continue
        out.append(
            HistoricalDay(
                instant=entry_dt,
                temp=_daily_temperature(item, 0.0),
                rain=_daily_precipitation(item, 0.0),
            )
        )
    return out


def _weather_for_target_date(
    merged_weather: dict[str, Any],
    weather: WeatherInputs,
    target_now: datetime,
) -> WeatherInputs:
    daily = _matching_daily_entry(merged_weather, target_now.date())
    if daily is None:
        return WeatherInputs(
            temperature=weather.temperature,
            humidity=weather.humidity,
            precipitation=weather.precipitation,
            wind_speed=weather.wind_speed,
            current_dt=int(target_now.timestamp()),
            historical=_historical_with_forecast(weather.historical, merged_weather, target_now),
            forecast=weather.forecast,
        )

    humidity = daily.get("humidity")
    wind = daily.get("wind_speed")
    return WeatherInputs(
        temperature=_daily_temperature(daily, weather.temperature),
        humidity=float(humidity) if humidity is not None else weather.humidity,
        precipitation=_daily_precipitation(daily, weather.precipitation),
        wind_speed=float(wind) if wind is not None else weather.wind_speed,
        current_dt=int(target_now.timestamp()),
        historical=_historical_with_forecast(weather.historical, merged_weather, target_now),
        forecast=weather.forecast,
    )


def calculate_condition(
    merged_weather: dict[str, Any],
    crag: CragConditionInputs | None = None,
    *,
    reference_now: datetime | None = None,
    target_now: datetime | None = None,
) -> ConditionResult:
    """
    Compute condition score from merged forecast JSON.

    ``reference_now`` defaults to current UTC; set in tests for deterministic output.
    """
    c = crag or CragConditionInputs()
    now = target_now or reference_now or datetime.now(timezone.utc)
    weather_base = weather_inputs_from_merged(merged_weather)
    weather = _weather_for_target_date(merged_weather, weather_base, now)
    factors: list[str] = []

    score = 100
    recent_precipitation_score = _recent_precipitation_score(weather.historical, now, factors)
    score -= 30 - recent_precipitation_score

    current_weather_score = _current_weather_score(weather, factors)
    score -= 25 - current_weather_score

    aspect_score = _aspect_score(c.aspect, weather.historical, now, factors)
    score -= 20 - aspect_score

    rock_type_score = _rock_type_score(
        c.rock_type, weather.historical, weather.precipitation, now, factors
    )
    score -= 15 - rock_type_score

    climbing_style_score = _climbing_style_score(c.climbing_types, score, factors)
    score -= 10 - climbing_style_score

    score = _apply_special_penalties(c, weather, score, now, factors)
    score = max(0, min(100, score))
    rec = _recommendation_for_score(score)
    last_updated = int(now.timestamp())
    return ConditionResult(
        score=score,
        recommendation=rec.value,
        factors=factors,
        last_updated_unix=last_updated,
    )


def calculate_condition_forecast(
    merged_weather: dict[str, Any],
    crag: CragConditionInputs | None = None,
    *,
    days: int = 14,
) -> list[dict[str, Any]]:
    c = crag or CragConditionInputs()
    current = merged_weather.get("current")
    if not isinstance(current, dict) or current.get("dt") is None:
        return []

    base_now = _to_utc_datetime(int(current["dt"]))
    out: list[dict[str, Any]] = []
    candidates = [(base_now + timedelta(days=offset)).date() for offset in range(days)]

    for d in candidates:
        target = datetime(
            year=d.year,
            month=d.month,
            day=d.day,
            hour=12,
            minute=0,
            second=0,
            tzinfo=timezone.utc,
        )
        result = calculate_condition(
            merged_weather,
            c,
            target_now=target,
        )
        out.append(
            {
                "date": d.isoformat(),
                "score": result.score,
                "recommendation": result.recommendation,
                "factors": result.factors,
                "lastUpdated": result.last_updated_unix,
            }
        )
    return out


def condition_from_merged_with_defaults(
    merged_weather: dict[str, Any],
    *,
    reference_now: datetime | None = None,
) -> ConditionResult:
    """Catalog defaults: unknown aspect, limestone, sport (§5.5)."""
    return calculate_condition(
        merged_weather,
        CragConditionInputs(),
        reference_now=reference_now,
    )


__all__ = [
    "calculate_condition",
    "calculate_condition_forecast",
    "condition_from_merged_with_defaults",
    "weather_inputs_from_merged",
]
