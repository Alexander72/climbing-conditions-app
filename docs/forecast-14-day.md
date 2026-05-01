# 14-Day Climbing Conditions Forecast

This document describes how the app exposes date-based climbing condition estimations up to 14 days ahead.

## API Contract

- Detailed crag responses (`GET /api/crags?detail_level=full` and `GET /api/crags/{id}`) now include:
  - `conditionScore`, `conditionRecommendation`, `conditionFactors`, `conditionLastUpdated` (backward compatible current snapshot)
  - `conditionForecast`: array of daily entries with:
    - `date` (`YYYY-MM-DD`, UTC date)
    - `score` (`0..100`)
    - `recommendation` (`excellent|good|fair|poor|dangerous`)
    - `factors` (string list)
    - `lastUpdated` (unix seconds)

## Forecast Horizon and Fallbacks

- Backend computes up to 14 daily condition entries from merged weather data.
- If upstream weather provides fewer than 14 daily points, `conditionForecast` includes all available points.
- The UI falls back to the legacy current condition when a selected date has no forecast entry.

## Caching and Resolution

- Forecast cache TTL remains 3600 seconds (`FORECAST_TTL_SECONDS`).
- Day summary cache TTL remains 7 days (`DAY_SUMMARY_TTL_DAYS`).
- Weather resolution keeps the historical 5-day summary window and trims daily forecast payload to 14 days.

## Partial Coverage

- The existing weather-cell cap for wide viewports still applies.
- When capped, unresolved crags return empty `conditionForecast` and null legacy condition fields.
