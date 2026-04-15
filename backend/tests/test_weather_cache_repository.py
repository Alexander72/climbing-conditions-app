"""T2: weather cache repository TTLs with moto DynamoDB (§3, §9)."""

import time
from datetime import date, timedelta

import boto3
from moto import mock_aws

from repositories.weather_cache_repository import WeatherCacheRepository
from services.weather_service import _midnight_unix_for_local_date


TABLE_NAME = "climbing-conditions-weather-test"


def _create_table(region: str = "eu-west-1") -> None:
    client = boto3.client("dynamodb", region_name=region)
    client.create_table(
        TableName=TABLE_NAME,
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


def _int_ttl(item: dict) -> int:
    t = item["ttl"]
    return int(t)


@mock_aws
def test_put_forecast_ttl_is_now_plus_3600_within_tolerance():
    _create_table()
    repo = WeatherCacheRepository(TABLE_NAME, region_name="eu-west-1")
    before = time.time()
    repo.put_forecast("u09tv", "{}", "2026-01-01T00:00:00Z")
    after = time.time()
    item = repo.get_forecast("u09tv")
    assert item is not None
    ttl = _int_ttl(item)
    assert int(before) + 3600 - 2 <= ttl <= int(after) + 3600 + 2


@mock_aws
def test_put_day_ttl_matches_midnight_helper_for_d_plus_seven():
    _create_table()
    repo = WeatherCacheRepository(TABLE_NAME, region_name="eu-west-1")
    d = date(2024, 6, 10)
    tz_name = "Europe/Paris"
    tz_offset = 0
    written = "2026-01-01T12:00:00Z"
    repo.put_day_summary("u09tv", d, "{}", written, tz_name, tz_offset)
    item = repo.get_day("u09tv", d)
    assert item is not None
    expected = _midnight_unix_for_local_date(
        d + timedelta(days=7), tz_name, tz_offset
    )
    assert _int_ttl(item) == expected


@mock_aws
def test_batch_get_day_items_returns_hits_for_up_to_five_dates():
    _create_table()
    repo = WeatherCacheRepository(TABLE_NAME, region_name="eu-west-1")
    dates = [
        date(2024, 6, 10),
        date(2024, 6, 11),
        date(2024, 6, 12),
        date(2024, 6, 13),
        date(2024, 6, 14),
    ]
    for d in dates:
        repo.put_day_summary("abc12", d, "{}", "2026-01-01T00:00:00Z", None, 3600)
    got = repo.batch_get_day_items("abc12", dates)
    assert set(got.keys()) == set(dates)
    assert all(got[d] is not None for d in dates)
    assert all("payload" in got[d] for d in dates)
