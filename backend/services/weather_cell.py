"""Weather cell identifiers: geohash precision-5 encode/decode for OWM coordinates (§2)."""

from __future__ import annotations

import geohash

WEATHER_CELL_PRECISION = 5


def cell_id_from_lat_lon(latitude: float, longitude: float) -> str:
    """Return the 5-character cell id for the given WGS84 coordinates (§2.1)."""
    return geohash.encode(latitude, longitude, precision=WEATHER_CELL_PRECISION)


def openweather_lat_lon_for_cell(cell_id: str) -> tuple[float, float]:
    """Cell center from ``cell_id``, rounded for OpenWeather query params (§2.2)."""
    lat_c, lon_c = geohash.decode(cell_id)
    return round(lat_c, 6), round(lon_c, 6)
