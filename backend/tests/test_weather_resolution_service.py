"""T3: weather resolution cache vs OpenWeather HTTP (§4, §9)."""

from __future__ import annotations

import asyncio
import json
from unittest.mock import AsyncMock, patch

import boto3
import httpx
from moto import mock_aws

from clients.openweather_client import ONE_CALL_DEFAULT, OpenWeatherClient
from repositories.weather_cache_repository import WeatherCacheRepository
from services.weather_resolution_service import _utc_now_iso_z, resolve_cell
from services.weather_service import _calendar_dates_oldest_first

TABLE = "weather-resolution-test"


def _create_table() -> None:
    boto3.client("dynamodb", region_name="eu-west-1").create_table(
        TableName=TABLE,
        BillingMode="PAY_PER_REQUEST",
        AttributeDefinitions=[
            {"AttributeName": "pk", "AttributeType": "S"},
            {"AttributeName": "sk", "AttributeType": "S"},
        ],
        KeySchema=[
            {"AttributeName": "pk", "KeyType": "HASH"},
            {"AttributeName": "sk", "KeyType": "RANGE"},
        ],
    )


def _day_payload() -> str:
    return json.dumps(
        {
            "temperature": {"min": 10.0, "max": 12.0},
            "precipitation": {"total": 0.5},
        }
    )


def _forecast_payload() -> dict:
    return {
        "timezone": "UTC",
        "timezone_offset": 0,
        "current": {},
        "hourly": [],
    }


@mock_aws
def test_all_cache_hits_zero_owm_http():
    _create_table()
    repo = WeatherCacheRepository(TABLE, region_name="eu-west-1")
    cell_id = "u09tv"
    fc = _forecast_payload()
    repo.put_forecast(cell_id, json.dumps(fc), _utc_now_iso_z())
    dates = _calendar_dates_oldest_first("UTC", 0, 5)
    today = dates[-1]
    for d in dates:
        written = _utc_now_iso_z() if d == today else "2020-01-01T00:00:00Z"
        repo.put_day_summary(
            cell_id,
            d,
            _day_payload(),
            written,
            "UTC",
            0,
        )

    async def _run() -> None:
        with patch.object(
            OpenWeatherClient,
            "fetch_forecast",
            new_callable=AsyncMock,
        ) as m_fc:
            with patch.object(
                OpenWeatherClient,
                "fetch_day_summary",
                new_callable=AsyncMock,
            ) as m_day:
                m_fc.side_effect = AssertionError("fetch_forecast must not be called")
                m_day.side_effect = AssertionError("fetch_day_summary must not be called")
                out = await resolve_cell(
                    cell_id,
                    api_key="dummy",
                    base_url=ONE_CALL_DEFAULT,
                    repository=repo,
                )
                assert out["timezone"] == "UTC"
                assert "historical" in out
                assert len(out["historical"]) == 5

    asyncio.run(_run())


@mock_aws
def test_all_cache_misses_one_forecast_and_five_day_calls():
    _create_table()
    repo = WeatherCacheRepository(TABLE, region_name="eu-west-1")
    cell_id = "u09tv"
    req = httpx.Request("GET", ONE_CALL_DEFAULT)
    fc_resp = httpx.Response(
        200,
        json=_forecast_payload(),
        request=req,
    )
    summ = {
        "temperature": {"min": 1.0, "max": 3.0},
        "precipitation": {"total": 0.1},
    }

    async def _run() -> None:
        with patch.object(
            OpenWeatherClient,
            "fetch_forecast",
            new_callable=AsyncMock,
        ) as m_fc:
            with patch.object(
                OpenWeatherClient,
                "fetch_day_summary",
                new_callable=AsyncMock,
            ) as m_day:
                m_fc.return_value = fc_resp
                m_day.return_value = summ
                out = await resolve_cell(
                    cell_id,
                    api_key="dummy",
                    base_url=ONE_CALL_DEFAULT,
                    repository=repo,
                )
                assert m_fc.await_count == 1
                assert m_day.await_count == 5
                assert "historical" in out
                assert len(out["historical"]) == 5

    asyncio.run(_run())


@mock_aws
def test_forecast_hit_all_days_miss_only_day_summaries():
    _create_table()
    repo = WeatherCacheRepository(TABLE, region_name="eu-west-1")
    cell_id = "u09tv"
    repo.put_forecast(cell_id, json.dumps(_forecast_payload()), _utc_now_iso_z())
    summ = {
        "temperature": {"min": 2.0, "max": 4.0},
        "precipitation": {"total": 0.0},
    }

    async def _run() -> None:
        with patch.object(
            OpenWeatherClient,
            "fetch_forecast",
            new_callable=AsyncMock,
        ) as m_fc:
            with patch.object(
                OpenWeatherClient,
                "fetch_day_summary",
                new_callable=AsyncMock,
            ) as m_day:
                m_fc.side_effect = AssertionError("forecast must not be called")
                m_day.return_value = summ
                await resolve_cell(
                    cell_id,
                    api_key="dummy",
                    base_url=ONE_CALL_DEFAULT,
                    repository=repo,
                )
                assert m_fc.await_count == 0
                assert m_day.await_count == 5

    asyncio.run(_run())


@mock_aws
def test_forecast_miss_all_days_hit_only_forecast():
    _create_table()
    repo = WeatherCacheRepository(TABLE, region_name="eu-west-1")
    cell_id = "u09tv"
    fc = _forecast_payload()
    dates = _calendar_dates_oldest_first("UTC", 0, 5)
    today = dates[-1]
    for d in dates:
        written = _utc_now_iso_z() if d == today else "2020-01-01T00:00:00Z"
        repo.put_day_summary(
            cell_id,
            d,
            _day_payload(),
            written,
            "UTC",
            0,
        )
    req = httpx.Request("GET", ONE_CALL_DEFAULT)
    fc_resp = httpx.Response(200, json=fc, request=req)

    async def _run() -> None:
        with patch.object(
            OpenWeatherClient,
            "fetch_forecast",
            new_callable=AsyncMock,
        ) as m_fc:
            with patch.object(
                OpenWeatherClient,
                "fetch_day_summary",
                new_callable=AsyncMock,
            ) as m_day:
                m_fc.return_value = fc_resp
                m_day.side_effect = AssertionError("day_summary must not be called")
                await resolve_cell(
                    cell_id,
                    api_key="dummy",
                    base_url=ONE_CALL_DEFAULT,
                    repository=repo,
                )
                assert m_fc.await_count == 1
                assert m_day.await_count == 0

    asyncio.run(_run())


@mock_aws
def test_today_stale_written_at_triggers_one_day_fetch():
    _create_table()
    repo = WeatherCacheRepository(TABLE, region_name="eu-west-1")
    cell_id = "u09tv"
    repo.put_forecast(cell_id, json.dumps(_forecast_payload()), _utc_now_iso_z())
    dates = _calendar_dates_oldest_first("UTC", 0, 5)
    today = dates[-1]
    for d in dates:
        if d < today:
            repo.put_day_summary(
                cell_id,
                d,
                _day_payload(),
                "2020-01-01T00:00:00Z",
                "UTC",
                0,
            )
        else:
            repo.put_day_summary(
                cell_id,
                d,
                _day_payload(),
                "2000-01-01T00:00:00Z",
                "UTC",
                0,
            )
    summ = {
        "temperature": {"min": 5.0, "max": 7.0},
        "precipitation": {"total": 1.0},
    }

    async def _run() -> None:
        with patch.object(
            OpenWeatherClient,
            "fetch_forecast",
            new_callable=AsyncMock,
        ) as m_fc:
            with patch.object(
                OpenWeatherClient,
                "fetch_day_summary",
                new_callable=AsyncMock,
            ) as m_day:
                m_fc.side_effect = AssertionError("forecast must not be called")
                m_day.return_value = summ
                await resolve_cell(
                    cell_id,
                    api_key="dummy",
                    base_url=ONE_CALL_DEFAULT,
                    repository=repo,
                )
                assert m_fc.await_count == 0
                assert m_day.await_count == 1

    asyncio.run(_run())
