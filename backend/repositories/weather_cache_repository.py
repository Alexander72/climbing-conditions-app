"""DynamoDB weather cache: forecast and per-day summary items (§3)."""

from __future__ import annotations

import time
import logging
from datetime import date, timedelta
from typing import Any

import boto3
from boto3.dynamodb.types import TypeDeserializer
from botocore.exceptions import ClientError

from services.weather_service import _midnight_unix_for_local_date

FORECAST_SK = "FORECAST#metric"
FORECAST_TTL_SECONDS = 3600
DAY_SUMMARY_TTL_DAYS = 7
logger = logging.getLogger(__name__)


def cell_partition_key(cell_id: str) -> str:
    return f"CELL#{cell_id}"


def day_sort_key(local_date: date) -> str:
    return f"DAY#{local_date.isoformat()}#metric"


class WeatherCacheRepository:
    """GetItem / BatchGetItem / PutItem for forecast and DAY rows."""

    def __init__(
        self,
        table_name: str,
        *,
        dynamodb_resource: Any | None = None,
        region_name: str | None = None,
        endpoint_url: str | None = None,
    ) -> None:
        self._table_name = table_name
        region = region_name or "eu-west-1"
        kwargs: dict[str, Any] = {"region_name": region}
        if endpoint_url is not None:
            kwargs["endpoint_url"] = endpoint_url
        resource = dynamodb_resource or boto3.resource("dynamodb", **kwargs)
        self._table = resource.Table(table_name)
        self._client = self._table.meta.client
        self._deser = TypeDeserializer()

    def _item_from_low_level(self, raw: dict[str, Any]) -> dict[str, Any]:
        """Moto batch_get often returns native values; AWS returns AttributeValue maps."""
        if raw and isinstance(raw.get("pk"), str):
            return dict(raw)
        return {k: self._deser.deserialize(v) for k, v in raw.items()}

    @staticmethod
    def _is_missing_table_error(exc: ClientError) -> bool:
        code = exc.response.get("Error", {}).get("Code")
        return code == "ResourceNotFoundException"

    def get_forecast(self, cell_id: str) -> dict[str, Any] | None:
        try:
            resp = self._table.get_item(
                Key={"pk": cell_partition_key(cell_id), "sk": FORECAST_SK},
            )
            return resp.get("Item")
        except ClientError as exc:
            if self._is_missing_table_error(exc):
                logger.warning(
                    "Weather cache table missing; continuing without cache in get_forecast"
                )
                return None
            raise

    def put_forecast(
        self, cell_id: str, payload_json: str, fetched_at: str
    ) -> None:
        ttl = int(time.time()) + FORECAST_TTL_SECONDS
        try:
            self._table.put_item(
                Item={
                    "pk": cell_partition_key(cell_id),
                    "sk": FORECAST_SK,
                    "payload": payload_json,
                    "fetched_at": fetched_at,
                    "ttl": ttl,
                },
            )
        except ClientError as exc:
            if self._is_missing_table_error(exc):
                logger.warning(
                    "Weather cache table missing; skipping put_forecast write"
                )
                return
            raise

    def put_day_summary(
        self,
        cell_id: str,
        d: date,
        payload_json: str,
        written_at: str,
        timezone_name: str | None,
        timezone_offset: int,
    ) -> None:
        ttl = _midnight_unix_for_local_date(
            d + timedelta(days=DAY_SUMMARY_TTL_DAYS), timezone_name, timezone_offset
        )
        try:
            self._table.put_item(
                Item={
                    "pk": cell_partition_key(cell_id),
                    "sk": day_sort_key(d),
                    "payload": payload_json,
                    "written_at": written_at,
                    "ttl": ttl,
                },
            )
        except ClientError as exc:
            if self._is_missing_table_error(exc):
                logger.warning(
                    "Weather cache table missing; skipping put_day_summary write"
                )
                return
            raise

    def get_day(self, cell_id: str, d: date) -> dict[str, Any] | None:
        try:
            resp = self._table.get_item(
                Key={"pk": cell_partition_key(cell_id), "sk": day_sort_key(d)},
            )
            return resp.get("Item")
        except ClientError as exc:
            if self._is_missing_table_error(exc):
                logger.warning(
                    "Weather cache table missing; continuing without cache in get_day"
                )
                return None
            raise

    def batch_get_day_items(
        self, cell_id: str, local_dates: list[date]
    ) -> dict[date, dict[str, Any] | None]:
        if not local_dates:
            return {}
        pk = cell_partition_key(cell_id)
        sk_to_date = {day_sort_key(d): d for d in local_dates}
        # Native attribute values — botocore serializes to Dynamo wire format.
        pending = [{"pk": pk, "sk": day_sort_key(d)} for d in local_dates]
        found: dict[date, dict[str, Any]] = {}
        while pending:
            chunk = pending[:100]
            pending = pending[100:]
            try:
                resp = self._client.batch_get_item(
                    RequestItems={
                        self._table_name: {"Keys": chunk},
                    },
                )
            except ClientError as exc:
                if self._is_missing_table_error(exc):
                    logger.warning(
                        "Weather cache table missing; continuing without cache in batch_get_day_items"
                    )
                    return {d: None for d in local_dates}
                raise
            for raw in resp.get("Responses", {}).get(self._table_name, []):
                item = self._item_from_low_level(raw)
                sk = item["sk"]
                if sk in sk_to_date:
                    found[sk_to_date[sk]] = item
            unproc = resp.get("UnprocessedKeys", {}).get(self._table_name, {})
            if unproc.get("Keys"):
                pending.extend(unproc["Keys"])

        return {d: found.get(d) for d in local_dates}

    def batch_get_items(
        self, keys: list[tuple[str, str]]
    ) -> list[dict[str, Any]]:
        """Arbitrary (pk, sk) keys; chunks of 100; returns items in no fixed order."""
        if not keys:
            return []
        out: list[dict[str, Any]] = []
        pending = [{"pk": pk, "sk": sk} for pk, sk in keys]
        while pending:
            chunk = pending[:100]
            pending = pending[100:]
            try:
                resp = self._client.batch_get_item(
                    RequestItems={self._table_name: {"Keys": chunk}},
                )
            except ClientError as exc:
                if self._is_missing_table_error(exc):
                    logger.warning(
                        "Weather cache table missing; continuing without cache in batch_get_items"
                    )
                    return []
                raise
            for raw in resp.get("Responses", {}).get(self._table_name, []):
                out.append(self._item_from_low_level(raw))
            unproc = resp.get("UnprocessedKeys", {}).get(self._table_name, {})
            if unproc.get("Keys"):
                pending.extend(unproc["Keys"])
        return out
