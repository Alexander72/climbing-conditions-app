"""Ensure the weather cache DynamoDB table exists (local / Docker only when endpoint is set).

Run once when adopting DynamoDB Local, or after wiping local data — not on every API boot.

    cd backend && python weather_cache_table_setup.py

Or: ``make ensure-weather-cache-table`` (same thing; loads ``.env``).
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


def ensure_weather_cache_table() -> None:
    """Describe table; on miss, create with pk/sk and TTL on ``ttl`` (§3.3, §8.2)."""
    table_name = os.environ.get("WEATHER_CACHE_TABLE")
    if not table_name:
        logger.warning("WEATHER_CACHE_TABLE is unset; skipping weather cache table setup")
        return

    endpoint_url = os.environ.get("AWS_ENDPOINT_URL_DYNAMODB") or None
    region = os.environ.get("AWS_REGION", "eu-west-1")
    kwargs: dict[str, Any] = {"region_name": region}
    if endpoint_url:
        kwargs["endpoint_url"] = endpoint_url

    client = boto3.client("dynamodb", **kwargs)
    try:
        client.describe_table(TableName=table_name)
        return
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code", "")
        if code != "ResourceNotFoundException":
            raise
    logger.info("Creating DynamoDB table %s", table_name)
    client.create_table(
        TableName=table_name,
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
    waiter = client.get_waiter("table_exists")
    waiter.wait(TableName=table_name)
    client.update_time_to_live(
        TableName=table_name,
        TimeToLiveSpecification={"Enabled": True, "AttributeName": "ttl"},
    )
    logger.info("Weather cache table %s is ACTIVE with TTL on ttl", table_name)


def main() -> None:
    """CLI entrypoint: load ``.env``, require ``WEATHER_CACHE_TABLE``, then ensure table."""
    from dotenv import load_dotenv

    load_dotenv()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    if not os.environ.get("WEATHER_CACHE_TABLE"):
        logger.error(
            "WEATHER_CACHE_TABLE is not set. Copy .env.example to .env and set it "
            "(e.g. climbing-conditions-weather-local for Docker Compose)."
        )
        sys.exit(1)
    ensure_weather_cache_table()


if __name__ == "__main__":
    main()
