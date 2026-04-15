"""Pytest hooks shared by the backend test suite."""

import os

import pytest


@pytest.fixture(scope="session", autouse=True)
def _strip_dynamodb_local_endpoint_for_moto() -> None:
    """Runs once before any test, after all test modules (and ``load_dotenv()``) are imported."""
    # Moto stubs the default AWS endpoint. A developer `.env` may set
    # AWS_ENDPOINT_URL_DYNAMODB for Docker Compose, which would bypass moto.
    os.environ.pop("AWS_ENDPOINT_URL_DYNAMODB", None)
    yield
