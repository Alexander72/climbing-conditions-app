"""T1: weather cell encode/decode and OpenWeather rounding (§2, §9)."""

import geohash

from services.weather_cell import (
    WEATHER_CELL_PRECISION,
    cell_id_from_lat_lon,
    openweather_lat_lon_for_cell,
)


def test_cell_id_fixed_lat_lon_origin():
    assert cell_id_from_lat_lon(0.0, 0.0) == "s0000"
    assert len(cell_id_from_lat_lon(0.0, 0.0)) == WEATHER_CELL_PRECISION


def test_cell_id_fixed_lat_lon_paris_area():
    assert cell_id_from_lat_lon(48.8566, 2.3522) == "u09tv"


def test_openweather_coordinates_round_decode_center():
    cell_id = "u09tv"
    lat_c, lon_c = geohash.decode(cell_id)
    lat, lon = openweather_lat_lon_for_cell(cell_id)
    assert lat == round(lat_c, 6)
    assert lon == round(lon_c, 6)
    assert lat == 48.845215
    assert lon == 2.351074
