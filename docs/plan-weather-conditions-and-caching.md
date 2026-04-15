# Specification: Weather cache, DynamoDB, backend condition scores

Authoritative specification. Execute **§10** in order without skipping steps.

---

## 1. Objectives

| # | Requirement |
|---|-------------|
| O1 | OpenWeather usage stays within **2000 calls per calendar day** (count every successful HTTP request to `api.openweathermap.org` made by this backend: One Call + `day_summary`). |
| O2 | Lambda remains **stateless**; all cache data is in **DynamoDB**. |
| O3 | Points in the same **weather cell** (geohash precision **5**, §2) share one cache entry and one upstream resolution path per TTL window (nominal edge length ≈ **4.9 km** at the equator per geohash definition). |
| O4 | After a successful **`day_summary`** for `(cell_id, local_date)` **`d`**, persist it with **`ttl`** in **§3.4**. Call **`day_summary`** again only when **§3.7** applies: **today’s** `written_at` refresh rule, **missing** DAY item, **absent `ttl` on a DAY item** (treat as expired), or **`ttl`** in the past per **§3.6**. |
| O5 | Forecast (One Call) cache **TTL = 3600 s** wall clock from write time; stale within **1 h** is acceptable. |
| O6 | **`GET /api/crags?detail_level=summary`**: behaviour and JSON shape **unchanged** from current production (no weather, no condition fields, no `weatherCells`, no `weatherPartial`). |
| O7 | **`GET /api/crags?detail_level=full`**: each crag row includes condition and cell fields defined in §6; response includes **`weatherCells`** and **`weatherPartial`** as defined. |
| O8 | Flutter **does not** call **`GET /api/weather`** for map markers, list, or crag detail after migration; **`GET /api/weather`** remains implemented and uses the **same** resolution code as crags. |
| O9 | Condition logic matches **`lib/domain/services/condition_calculator.dart`** and numeric thresholds from **`lib/core/config.dart`**; golden tests in §9. |
| O10 | **Docker Compose** runs backend + DynamoDB Local with the same access patterns as AWS (§8). |

---

## 2. Weather cell

### 2.1 Algorithm

1. Input: `latitude`, `longitude` (WGS84, degrees).
2. Compute `cell_id = geohash.encode(latitude, longitude, precision=5)` using **`python-geohash==0.8.5`** (PyPI package name **`python-geohash`**; installed import is **`import geohash`** — single module `geohash.py` from that distribution).
3. `cell_id` is exactly **5** characters from the geohash base32 alphabet **`0123456789bcdefghjkmnpqrstuvwxyz`**. No prefix. It is the sole public identifier for the cell in API and cache keys.

### 2.2 Coordinates passed to OpenWeather

1. Decode center: `lat_c, lon_c = geohash.decode(cell_id)` — **`decode`** returns **`(latitude, longitude)`** tuple (cell center), per `python-geohash` 0.8.5 `decode(hashcode)`.
2. Call OpenWeather with `lat = round(lat_c, 6)`, `lon = round(lon_c, 6)`.

### 2.3 Historical local dates and Dynamo sort keys

1. After One Call succeeds, read `timezone` (string or null) and `timezone_offset` (int seconds) from the JSON.
2. Build the list of **five** local calendar dates **oldest first** using the existing functions **`_calendar_dates_oldest_first`** and **`_midnight_unix_for_local_date`** in `backend/services/weather_service.py` (same logic as today).
3. For each date `d`, the Dynamo **sort key date component** is **`d.isoformat()`** (string `YYYY-MM-DD`).

---

## 3. DynamoDB

### 3.1 Store

All weather cache data lives in **one** DynamoDB table. **S3 is not used** for this feature.

### 3.2 Table physical name

| Environment | Table name value |
|-------------|------------------|
| AWS (SAM) | CloudFormation resource creates table; CloudFormation output or `!Sub` name **`climbing-conditions-weather-${Stage}`** where `Stage` is SAM parameter `Stage` (`dev` \| `prod`). Lambda env **`WEATHER_CACHE_TABLE`** = that table’s name. |
| Docker Compose | **`WEATHER_CACHE_TABLE=climbing-conditions-weather-local`** |

### 3.3 Key schema

- **Partition key** `pk` (String).
- **Sort key** `sk` (String).
- **Billing:** `PAY_PER_REQUEST`.
- **TTL:** attribute name **`ttl`**, type Number (epoch seconds). **Forecast** and **DAY** items both set **`ttl`** (different formulas in **§3.4**). DynamoDB deletes items **on or after** that time (best-effort).

### 3.4 Item types

**Forecast item**

| Attribute | Type | Value |
|-----------|------|--------|
| `pk` | S | `CELL#<cell_id>` |
| `sk` | S | `FORECAST#metric` |
| `payload` | S | **Entire** One Call JSON response body as a **single JSON string** (UTF-8), identical to successful `fetch_forecast` → `response.json()` before attaching `historical`. |
| `fetched_at` | S | UTC ISO-8601 with `Z`, written at write time. |
| `ttl` | N | `int(time.time()) + 3600` at write time. |

**Day summary item**

| Attribute | Type | Value |
|-----------|------|--------|
| `pk` | S | `CELL#<cell_id>` |
| `sk` | S | `DAY#<YYYY-MM-DD>#metric` where `<YYYY-MM-DD>` is the local calendar date from §2.3. |
| `payload` | S | Raw **`day_summary`** JSON object as returned by OWM, serialized to one JSON string. |
| `written_at` | S | UTC ISO-8601 with `Z`, written at write time. |
| `ttl` | N | **Expiry for data day `d`:** integer Unix seconds = **`_midnight_unix_for_local_date(d + timedelta(days=7), tz_name, tz_offset)`** using the same **`tz_name`**, **`tz_offset`**, and helper **`_midnight_unix_for_local_date`** as **`weather_service.py`**, where **`d`** is the **`date`** object for **`YYYY-MM-DD`** in the **`DAY#<YYYY-MM-DD>#metric`** sort key. **Semantics:** the cache entry for summary day **`d`** may be deleted **on or after** local midnight at the **start** of calendar day **`d + 7 days`** — i.e. after the **six** local calendar days **`d+1`** … **`d+6`** have fully elapsed after day **`d`**. |

### 3.5 Operations

| Step | Operation |
|------|-----------|
| Read forecast | `GetItem` on `pk`, `sk` above. |
| Read up to 5 days for one cell | `BatchGetItem` with 5 keys (same `pk`, different `sk`). |
| Read many cells | Issue `BatchGetItem` requests in chunks of **≤ 100 keys** until all keys read. |
| Write forecast | `PutItem` (full replace). |
| Write day | After a successful **`day_summary`** HTTP response for this **`d`**, **`PutItem`** full replace **without** `ConditionExpression`, setting **`payload`**, **`written_at`**, and **`ttl`** as in **§3.4**. Applies both to first insert and to every refresh (**today** `written_at` rule, **DAY miss**, or overwrite after fetch). |

### 3.6 Cache hit / miss

**Forecast item**

- **Miss** if item does not exist **or** current Unix time **`>= int(ttl)`** (treat as miss even if Dynamo has not deleted the row yet).
- **Hit** otherwise: parse **`payload`** string to dict.

**DAY summary item**

- **Miss** if item does not exist **or** attribute **`ttl`** is missing **or** current Unix time **`>= int(ttl)`**.
- **Hit** otherwise: parse **`payload`** string to dict.

### 3.7 Day summary fetch decision

Let **`dates`** be the list returned by **`_calendar_dates_oldest_first(..., days=5)`** (length 5, oldest → newest). Define **`today_local = dates[-1]`** (newest local calendar date in the cell’s timezone context).

For each **`d`** in **`dates`** (iterate **oldest first**, same order as today’s **`_build_historical_daily`**):

1. Read Dynamo item with **`sk = DAY#<d.isoformat()>#metric`** (via batch result or `GetItem`).
2. If the item is a **DAY hit** per **§3.6** and **`d < today_local`**: use cached **`payload`** only; **zero** OWM `day_summary` calls for this **`d`**.
3. If the item is a **DAY hit** per **§3.6** and **`d == today_local`**: if **`written_at`** (ISO `Z` parsed to aware UTC) is **strictly less than 3600 seconds** before **`datetime.now(timezone.utc)`**, use cache only; else **call** `day_summary`, then **`PutItem`** overwrite per **§3.5** (no condition).
4. If the item is a **DAY miss** per **§3.6** (missing, no **`ttl`**, or expired): **call** `day_summary`, then **`PutItem`** per **§3.5** “Write day”.

### 3.8 AWS SAM (`backend/template.yaml`)

1. Add `AWS::DynamoDB::Table` with `BillingMode: PAY_PER_REQUEST`, `AttributeDefinitions` + `KeySchema` for `pk` / `sk`, `TimeToLiveSpecification` enabled on attribute `ttl`.
2. Add to `ClimbingConditionsFunction.Properties.Environment.Variables`: `WEATHER_CACHE_TABLE: !Ref <TableLogicalId>`.
3. Add IAM policy statement allowing `dynamodb:GetItem`, `dynamodb:BatchGetItem`, `dynamodb:PutItem` on table ARN `!GetAtt <TableLogicalId>.Arn`.

### 3.9 Python dependencies

Add to `backend/requirements.txt` (exact pins):

```text
boto3==1.35.99
python-geohash==0.8.5
```

---

## 4. Weather resolution service

### 4.1 Module

New file **`backend/services/weather_resolution_service.py`** (exact path).

**Public coroutine:** **`async def resolve_cell(cell_id: str) -> dict[str, Any]`** (merged forecast JSON shape).

Responsibilities:

1. Given **`cell_id`**, compute OWM coordinates with **`geohash.decode(cell_id)`** and **§2.2** rounding (do not use the client’s raw lat/lon for OWM).
2. Load or fetch forecast JSON for that cell (§3.6–3.7).
3. From forecast JSON, compute local dates and `summary_url` using existing `day_summary_url` from `clients/openweather_client.py` and helpers from `weather_service.py`.
4. For each of the five dates, resolve `day_summary` per §3.7.
5. Build **`historical`** list exactly as **`_build_historical_daily`** in `weather_service.py` does today (`dt`, `temp`, `rain` per day).
6. Return **merged dict**: `{**forecast_dict, "historical": historical_list}` where `historical` is omitted if empty (same as current behaviour when all summaries fail).

On upstream or configuration failure, raise **`WeatherServiceError`** with the same status codes and `detail` structure as **`get_weather_forecast`** today (`weather_service.py`). Read **`OPENWEATHER_API_KEY`**, **`OPENWEATHER_BASE_URL`** from **`os.environ`** using the same rules as the current **`get_weather_forecast`**.

### 4.2 Refactor

**`get_weather_forecast(lat, lon, ...)`** in `weather_service.py` must:

1. Compute `cell_id` from `lat`, `lon` (§2.1).
2. Call **`weather_resolution_service.resolve_cell(cell_id)`** (§4.1).
3. Return the merged dict.

**`OpenWeatherClient`** and **`OpenWeatherMap`** HTTP behaviour stay the thin client; resolution owns cache + orchestration.

### 4.3 OWM HTTP concurrency

Across a **single** Lambda / request invocation, at most **4** concurrent outbound OWM HTTP requests at any time (use `asyncio.Semaphore(4)` around `fetch_forecast` and each `fetch_day_summary`).

---

## 5. Crags enrichment

### 5.1 Module

New file **`backend/services/crags_weather_enrichment_service.py`**.

Input: list of crag dicts from **`list_crags_in_bbox`** (same shape as today).

### 5.2 Cell grouping and cap

1. For each crag, compute `cell_id` from `row["latitude"]`, `row["longitude"]` (float).
2. Collect **unique** `cell_id` values.
3. Sort unique `cell_id` **lexicographically ascending**.
4. Keep only the **first 40** entries in that sorted list. Call these **resolved cells**. Any crag whose `cell_id` is **not** in resolved cells is a **capped crag**.

### 5.3 Weather fetch

For each `cell_id` in **resolved cells**, in **lexicographic order of `cell_id`**, call **`weather_resolution_service.resolve_cell(cell_id)`** once **before** the next cell (strictly **sequential** cell processing). The **§4.3** semaphore still wraps each OWM request inside resolution.

### 5.4 `weatherCells` map

1. Keys are `cell_id` strings.
2. Value is the **exact** merged dict from §4.1 (forecast + `historical` when present), **JSON-serializable** same as today’s `get_weather_forecast` return.
3. One map entry per resolved cell for which resolution **returned without raising** `WeatherServiceError`. If resolution raises for a cell, **omit** that `cell_id` from `weatherCells` (no partial entry).

### 5.5 Condition fields per crag

New module **`backend/services/condition_service.py`**: port Dart `ConditionCalculator.calculateCondition` inputs/outputs.

**Crag inputs for catalog rows** (until catalog gains fields):

| Field | Value |
|-------|--------|
| aspect | same as Flutter default for fetched crags: **unknown** |
| rock_type | **limestone** |
| climbing_types | **sport** only |

Map these to the same internal representations the Dart code uses (`Aspect.unknown`, `RockType.limestone`, `[ClimbingType.sport]`).

**Weather input:** Build the in-memory structure the calculator needs from the merged dict for that crag’s `cell_id` (current + hourly + historical + precipitation). Match fields read by **`condition_calculator.dart`** and **`Weather` entity** / parsing in **`BackendApiClient._parseWeatherResponse`**.

**Output JSON fields on each crag** (camelCase keys, `detail_level=full` only):

| Key | Type | Rule |
|-----|------|------|
| `weatherCellId` | string | Always the crag’s `cell_id` from §2.1. |
| `conditionScore` | int \| null | `null` if crag is capped, or resolution failed for its cell, or `weatherCells` has no entry for its cell. Else integer **0–100**. |
| `conditionRecommendation` | string \| null | `null` when `conditionScore` is `null`. Else Dart enum **`.name`**: one of **`excellent`**, **`good`**, **`fair`**, **`poor`**, **`dangerous`**. |
| `conditionFactors` | array of string | Empty array `[]` when `conditionScore` is `null`. Else list of factor strings from the port (same strings as Dart `factors` list). |
| `conditionLastUpdated` | int \| null | Unix seconds UTC when score was computed; `null` when `conditionScore` is `null`. |
| `weatherAsOf` | string \| null | `fetched_at` from Dynamo forecast item used for that resolution, as ISO-8601 `Z`; `null` when no forecast was used successfully. |

### 5.6 `weatherPartial` (top-level, `detail_level=full` only)

- **`weatherPartial`: `true`** if any crag in the response is a **capped crag** (§5.2).
- **`weatherPartial`: `false`** otherwise.

### 5.7 Controller

**`backend/controllers/crags.py`**

1. If `detail_level == "summary"`: use response model **`CragsSummaryResponse`** with field **`crags` only** (no `weatherCells`, no `weatherPartial` keys in JSON).
2. If `detail_level == "full"`: use response model **`CragsFullResponse`** with fields **`crags`**, **`weatherCells`**, **`weatherPartial`**; after `list_crags_in_bbox`, run enrichment and populate all three fields.

---

## 6. HTTP API contracts

### 6.1 `GET /api/crags` — `detail_level=summary`

- Query params: unchanged.
- Response body: JSON object **`{ "crags": [ ... ] }`** only — same per-item fields as today’s **`CragItem`** list. Pydantic model name **`CragsSummaryResponse`** (replaces current **`CragsResponse`** for this route).

### 6.2 `GET /api/crags` — `detail_level=full`

Response JSON object:

```json
{
  "crags": [ /* each element includes base crag fields plus §5.5 fields */ ],
  "weatherCells": { "<cell_id>": { /* merged One Call + historical */ } },
  "weatherPartial": false
}
```

- **`weatherCells`**: always present (empty object `{}` if no cell succeeded).
- **`weatherPartial`**: always present, boolean.

Pydantic: **`CragFullItem`** contains every field on **`CragItem`** today plus **`weatherCellId`**, **`conditionScore`**, **`conditionRecommendation`**, **`conditionFactors`**, **`conditionLastUpdated`**, **`weatherAsOf`** (§5.5). **`CragsFullResponse`** has **`crags: list[CragFullItem]`**, **`weatherCells: dict[str, dict[str, Any]]`**, **`weatherPartial: bool`**.

### 6.3 `GET /api/crags/{crag_id}`

1. **Route:** register **`@router.get("/crags/{crag_id:path}")`** so `crag_id` can contain **`:`** (format **`{country}:{param_id}`** or **`{country}:{nid}`** or **`{country}:{lat},{lng}`** per §6.3).
2. **Catalog lookup:** Use **`CragRepository`** (same as `list_crags_in_bbox`). Iterate **country codes** from **`get_country_bboxes()`** sorted **lexicographically ascending**. For each country, call **`load_crags_for_country(country)`** and scan rows **in file iteration order**. For each row, compute **`id`** with the same rules as **`list_crags_in_bbox`** in `backend/services/crag_service.py`: if `param_id` set then `f"{country}:{param_id}"`; else if `id` field set then `f"{country}:{nid}"`; else `f"{country}:{lat:.6f},{lng:.6f}"`. **Stop** at the first row where this equals `crag_id`. If no row matches after all countries, respond **`404`** with FastAPI **`HTTPException`**.
3. **Response body:** Pydantic model **`CragDetailResponse`** serializes to:

```json
{
  "crag": { },
  "weatherCells": { },
  "weatherPartial": false
}
```

where **`crag`** is one **`CragFullItem`**, **`weatherCells`** has **zero or one** entry (the cell for that crag) using the same inner dict shape as **`GET /api/crags` full tier**, and **`weatherPartial`** is the literal boolean **`false`**.

4. Enrichment: always compute for that one crag’s cell (cell cap **does not apply**; exactly **one** cell).

### 6.4 `GET /api/weather`

- Query params: unchanged (`lat`, `lon`).
- Implementation: **`get_weather_forecast`** only via **`weather_resolution_service`** (§4.2).
- Response body: unchanged shape from today.

---

## 7. Flutter (post-backend deploy)

1. **`BackendApiClient`**: parse `weatherCells`, `weatherPartial`, and per-crag condition fields for `detail_level=full` crag list; add `getCragById` calling **`GET /api/crags/{id}`** with URL encoding for the path segment if required by `http` package.
2. **`CragModel` / entity**: add nullable / non-null fields matching §5.5 and `weatherCellId`.
3. **`CragMarker`**: remove **`WeatherProvider.fetchWeather`**; use **`conditionScore`** from entity for colouring when detailed.
4. **`CragListScreen`**, **`CragDetailScreen`**: remove weather fetches; detail loads **`getCragById`** (or equivalent) and builds **`Weather`** from **`weatherCells[weatherCellId]`** using existing **`_parseWeatherResponse`** logic extracted to a shared function.
5. **`getWeather`**: unused in production paths after migration; keep method until release branch deletes it.

---

## 8. Docker Compose and local AWS SDK

### 8.1 `backend/docker-compose.yml`

Add service **`dynamodb-local`**:

| Key | Value |
|-----|--------|
| `image` | `amazon/dynamodb-local:latest` |
| `ports` | `"8001:8000"` |

Do **not** override **`command`** or **`entrypoint`**. Use the image defaults.

Data is ephemeral unless you add a volume + DynamoDB Local persistence flags; table creation is still a **separate one-off** (or idempotent) step — **`python weather_cache_table_setup.py`** or **`make ensure-weather-cache-table`** from **`backend/`** after **`docker compose up`**, not on every FastAPI boot.

Add to **`backend`** service:

| Key | Value |
|-----|--------|
| `depends_on` | `dynamodb-local` |
| `env_file` | **`backend/.env`** (required) — includes `OPENWEATHER_*`, dummy AWS creds, `WEATHER_CACHE_TABLE`, `AWS_ENDPOINT_URL_DYNAMODB=http://dynamodb-local:8000`, etc. |

The compose file lives next to **`Dockerfile`** under **`backend/`**; **`build`** and **`volumes`** use `.` relative to that directory.

### 8.2 Table creation

**Separate setup** (not FastAPI lifespan): run **`backend/weather_cache_table_setup.py`** (or **`make ensure-weather-cache-table`** from **`backend/`**) when adopting DynamoDB Local (or after wiping local data). Documented in **`backend/README.md`**.

1. Create boto3 client `dynamodb` with `endpoint_url=os.environ["AWS_ENDPOINT_URL_DYNAMODB"]` **only when** that variable is set; otherwise `endpoint_url=None`.
2. Call **`describe_table(TableName=WEATHER_CACHE_TABLE)`**; if `ResourceNotFoundException`, call **`create_table`** with the key schema and TTL from §3.3–3.4.
3. Wait until table status **`ACTIVE`**, then enable TTL on **`ttl`**.

### 8.3 Documentation

**`backend/README.md`**: document **Weather cache table** setup (`weather_cache_table_setup.py` / `make ensure-weather-cache-table`) and Docker Compose one-liner; **“Docker”** subsection: from **`backend/`**, run `docker compose up`, ports as before; table creation is explicit setup, not app startup.

### 8.4 `backend/.env.example`

Append lines (with comments):

```env
# Weather cache — table name required in Lambda; same value used locally
WEATHER_CACHE_TABLE=climbing-conditions-weather-local
# Local Docker only — omit these three lines in Lambda (real AWS endpoint + IAM role)
# AWS_ENDPOINT_URL_DYNAMODB=http://dynamodb-local:8000
# AWS_ACCESS_KEY_ID=local
# AWS_SECRET_ACCESS_KEY=local
# AWS_REGION=eu-west-1
```

---

## 9. Tests

| # | Scope | Requirement |
|---|--------|-------------|
| T1 | `weather_cell` | Unit tests: fixed `(lat, lon)` → fixed `cell_id`; decode center rounds to §2.2. |
| T2 | `weather_cache_repository` | **`moto`** mocked DynamoDB; **`ttl`** on forecast writes equals **`now+3600`** (within test tolerance); **`ttl`** on DAY writes equals **`_midnight_unix_for_local_date(d + timedelta(days=7), …)`** for fixture **`d`**, **`tz_name`**, **`tz_offset`**. |
| T3 | `weather_resolution_service` | Mock httpx / client: when forecast + all five DAY rows are **hits** per **§3.6**, **zero** OWM HTTP calls; when forecast miss or any DAY **miss** (missing, no **`ttl`**, or **`time.time() >= ttl`**), assert exact One Call / `day_summary` counts. |
| T4 | `condition_service` | Golden fixtures: input JSON files → expected `conditionScore`, `conditionRecommendation.name`, `conditionFactors` list identical to Dart. |
| T5 | API | **`GET /api/crags`** summary: response JSON has only **`crags`**. Full: has **`crags`**, **`weatherCells`**, **`weatherPartial`**; with mocked resolution, scores present. |
| T6 | `GET /api/crags/{crag_id:path}` | Known id returns 200 and **`weatherPartial` false**; unknown id **404**. |

---

## 10. Implementation sequence

Execute in this order; do not skip.

1. Add **`python-geohash==0.8.5`**, **`boto3==1.35.99`** to **`backend/requirements.txt`** (§3.9).
2. Implement **`services/weather_cell.py`** (encode/decode + round per §2) + **T1**.
3. Implement **`repositories/weather_cache_repository.py`** + **T2**.
4. SAM table + IAM + **`WEATHER_CACHE_TABLE`** (§3.8); **`backend/docker-compose.yml`** + backend env (§8.1); **lifespan** create-table (§8.2); **`.env.example`** + **`README`** (§8.3–8.4).
5. Implement **`services/weather_resolution_service.py`** + wire **`get_weather_forecast`** (§4) + **T3** + **`/api/weather`** unchanged externally.
6. Implement **`services/condition_service.py`** + **T4**.
7. Implement **`services/crags_weather_enrichment_service.py`** + extend **`controllers/crags.py`** for **`detail_level=full`** (§5–6) + **T5**.
8. Add **`GET /api/crags/{crag_id:path}`** + **T6**.
9. Flutter changes (§7).

### Implementation progress (handoff)

Compact status for picking up in a new session. Authoritative behaviour remains in §1–§9 above.

| §10 step | Status | Notes |
|----------|--------|--------|
| **1** Deps (`python-geohash`, `boto3`, `moto`) | **Done** | `backend/requirements.txt` |
| **2** `services/weather_cell.py` + **T1** | **Done** | `tests/test_weather_cell.py` |
| **3** `repositories/weather_cache_repository.py` + **T2** | **Done** | `tests/test_weather_cache_repository.py` |
| **4** Infra + local docs | **Done (evolved)** | SAM: `WeatherCacheTable` + IAM + `WEATHER_CACHE_TABLE` in `template.yaml`. Compose: **`backend/docker-compose.yml`** — **`amazon/dynamodb-local`**, host **`8001:8000`**, `AWS_ENDPOINT_URL_DYNAMODB=http://dynamodb-local:8000` in `.env`. Table ensure is **not** FastAPI lifespan: **`weather_cache_table_setup.py`** / **`make ensure-weather-cache-table`**. README + `.env.example` + root `README.md`. **`Dockerfile`**: builder installs **`gcc`/`g++`** for **python-geohash** build on slim. **`tests/conftest.py`**: session autouse removes `AWS_ENDPOINT_URL_DYNAMODB` so **moto** tests are not sent to a real local endpoint. |
| **5** `weather_resolution_service.py` + wire `get_weather_forecast` + **T3** + `/api/weather` | **Done** | `services/weather_resolution_service.py`, `build_historical_from_day_summaries` in `weather_service.py`, `tests/test_weather_resolution_service.py` |
| **6** `condition_service.py` + **T4** | **Done** | `services/condition_service.py`; types in `models/condition/` (`enums.py`, `dto.py`, `constants.py`, `merged_weather.py`); golden JSON under `tests/fixtures/condition/`; **`tests/test_condition_service.py`**. |
| **7** `crags_weather_enrichment_service.py` + crags `full` + **T5** | **Done** | `services/crags_weather_enrichment_service.py`; `controllers/crags.py` — **`CragsSummaryResponse`** / **`CragsFullResponse`**, **`CragFullItem`**, `detail_level=full` runs enrichment; **`default_weather_cache_repository()`** in `weather_resolution_service.py`; **`tests/test_crags_api.py`**, **`tests/test_crags_weather_enrichment.py`**. |
| **8** `GET /api/crags/{crag_id:path}` + **T6** | **Done** | `controllers/crags.py` — **`CragDetailResponse`**, route before list route; **`find_crag_by_id`** + **`crag_id_for_catalog_row`** in `crag_service.py`; **`enrich_crag_detail`** in `crags_weather_enrichment_service.py`; **`tests/test_crags_api.py`** (200 + **`weatherPartial` false**, 404); **`tests/test_crag_catalog.py`** (`find_crag_by_id`). |
| **9** Flutter §7 | **Done** | `BackendApiClient`: `parseMergedWeatherJson`, `fetchCragsDetailedByBBox` (crags + `weatherPartial`), `getCragById` + `CragDetailApiResult`; `Crag` / `CragModel` + DB v4 columns; `CragRepository.fetchCragDetailFromBackend`, `refreshDetailedCragsByBBox` → `bool`; `CragProvider`: `viewportWeatherPartial`, `loadCragDetailFromBackend`; `CragMarker` / list / detail use backend scores + detail endpoint; `getWeather` retained. |

**Follow-ups**

- **Orphans:** After switching compose services, run **`docker compose down --remove-orphans`** from **`backend/`** if stale containers (e.g. old **LocalStack**) remain.

---

## 11. Fixed constants summary

| Constant | Value |
|----------|--------|
| Geohash precision | **5** |
| Geohash package | **`python-geohash==0.8.5`** |
| OWM lat/lon decimals | **6** |
| Forecast cache TTL | **3600** seconds |
| Today’s day_summary refresh interval | **3600** seconds since `written_at` |
| Max cells per bbox `detail_level=full` | **40** (lexicographic order) |
| Max concurrent OWM HTTP | **4** |
| Dynamo PK prefix | **`CELL#`** |
| Forecast SK | **`FORECAST#metric`** |
| Day SK pattern | **`DAY#<YYYY-MM-DD>#metric`** |
| TTL attribute name | **`ttl`** (forecast and DAY items) |
| Historical DAY `ttl` value | **`_midnight_unix_for_local_date(d + timedelta(days=7), tz_name, tz_offset)`** (same **`d`**, **`tz_*`** as when writing that DAY row) |
| Local DynamoDB host port (host machine) | **8001** |
| Local table name | **`climbing-conditions-weather-local`** |
| Dummy AWS region (Docker) | **`eu-west-1`** |
| DynamoDB Local image | **`amazon/dynamodb-local:latest`** (no digest pin; `docker compose pull dynamodb-local` updates it) |

---

*End of specification.*
