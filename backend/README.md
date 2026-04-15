# Climbing Conditions — Backend API

A lightweight FastAPI service that proxies OpenWeatherMap for weather and serves crag locations from **bundled JSON** (no third-party crag API). The Flutter app only talks to this backend. Runs locally as a plain Python server or Docker container, and deploys to AWS as a Lambda function behind API Gateway.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check — returns `{"status": "ok"}` |
| `GET` | `/api/weather?lat=&lon=` | Current weather + hourly forecast from OpenWeatherMap |
| `GET` | `/api/crags` | Crags inside a bounding box (see below) |

### `GET /api/crags`

**Query parameters (all required):** `min_lat`, `max_lat`, `min_lng`, `max_lng`  
**Optional:** `detail_level` — `summary` (default) or `full` (sets `isSummaryOnly` on each item for the client).

The backend loads `data/crags/<country>.json` for every country whose coverage bbox (see `data/crag_country_bboxes.json`) overlaps the request bbox, merges results, and returns only crags whose coordinates fall inside the request bbox.

**Response shape:**

```json
{
  "crags": [
    {
      "id": "be:corphalie-huy",
      "name": "Corphalie (Huy)",
      "latitude": 50.538678,
      "longitude": 5.260767,
      "country": "be",
      "isSummaryOnly": true,
      "routeCount": 123,
      "sportCount": 87,
      "tradNPCount": 36,
      "boulderCount": 0,
      "dwsCount": 0,
      "gradeHistogram": [{ "grade": "6a", "count": 12 }]
    }
  ]
}
```

Optional route fields are omitted when missing from the source row. `gradeHistogram` uses French sport grade labels derived from bundled `data/grades.json`.

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENWEATHER_API_KEY` | **Yes** | — | OpenWeatherMap One Call API 3.0 key |
| `OPENWEATHER_BASE_URL` | No | `https://api.openweathermap.org/data/3.0/onecall` | OWM endpoint (override for testing) |
| `WEATHER_CACHE_TABLE` | **Yes** (Lambda / full weather path) | — | DynamoDB table name for the weather cell cache (see SAM stack output) |
| `AWS_ENDPOINT_URL_DYNAMODB` | No | — | Set for DynamoDB Local in Compose (e.g. `http://dynamodb-local:8000`); omit in Lambda |
| `AWS_REGION` | No | `eu-west-1` | AWS region for DynamoDB clients |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | No | — | Dummy `local` values are set in Compose for DynamoDB Local only |
| `BACKEND_PORT` | No | `8000` | Host port mapped in `backend/docker-compose.yml` (used for `${BACKEND_PORT}` when you run Compose from `backend/`) |

---

## Weather cache table (DynamoDB)

The API expects a DynamoDB table named by **`WEATHER_CACHE_TABLE`** when weather caching is in use. The app **does not** create that table on startup.

| Where you run | What to do |
|---------------|------------|
| **AWS (SAM deploy)** | CloudFormation creates `climbing-conditions-weather-${Stage}`. Set **`WEATHER_CACHE_TABLE`** in Lambda to that name (the template does this). No separate script. |
| **DynamoDB Local** (Docker Compose or host on port **8001**) | From **`backend/`**, with **`backend/.env`** configured (including **`AWS_ENDPOINT_URL_DYNAMODB`** when using Local), run **once** after DynamoDB Local is reachable: `make ensure-weather-cache-table` or `python weather_cache_table_setup.py`. Safe to re-run (idempotent: `describe_table`, then `create_table` + TTL only if missing). |

**Docker Compose (first time or after wiping Local):** with the stack up (or at least **dynamodb-local** healthy), from **`backend/`**:

```bash
docker compose run --rm backend python weather_cache_table_setup.py
```

Then start or restart the **backend** service as usual.

### Viewing tables in a browser (DynamoDB Local)

[Dynamodb-admin](https://www.npmjs.com/package/dynamodb-admin) lists and edits items in a table UI. It defaults to access key **`key`** / **`secret`**; this backend uses **`local` / `local`** with DynamoDB Local (see `.env.example`), so pass the same env vars as below or the UI may show **no tables**. **DynamoDB Local** is on the host at port **8001**; use **`-p 8002`** (or another free port) for the admin web server so it does not clash with DynamoDB’s port **8001** in `docker-compose.yml`.

```bash
AWS_REGION=eu-west-1 AWS_ACCESS_KEY_ID=local AWS_SECRET_ACCESS_KEY=local npx dynamodb-admin --dynamo-endpoint http://localhost:8001 -p 8002 -o
```

`-o` opens the UI in your default browser.

---

## Local development

Three options — pick the one that suits your setup.

### Option A — Plain Python (fastest iteration)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # fill in OPENWEATHER_API_KEY + WEATHER_CACHE_TABLE / AWS_* if using DynamoDB Local
# If using DynamoDB Local: start it, then once — make ensure-weather-cache-table
uvicorn main:app --reload
```

API available at `http://localhost:8000`.  
Changes to `*.py` files are picked up automatically by `--reload`.

Run the Flutter app against it:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

---

### Option B — Docker Compose (no Python install needed)

```bash
cd backend
cp .env.example .env   # fill in OPENWEATHER_API_KEY
docker compose up --build
# In another terminal (after dynamodb-local is up), once per fresh volume:
docker compose run --rm backend python weather_cache_table_setup.py
```

API available at `http://localhost:8000`.

### Docker

Compose is defined in **`backend/docker-compose.yml`**. From the **`backend/`** directory, run `docker compose up` (optionally `--build`). The **`Dockerfile`** builder stage installs **`gcc`/`g++`** so **`python-geohash`** can compile its native extension inside **`python:3.12-slim`** (the final runtime image stays slim). Docker Compose loads **`backend/.env`** for both container environment and interpolation of `${BACKEND_PORT}` in the compose file. The **backend** service listens at `http://localhost:${BACKEND_PORT:-8000}`. **DynamoDB Local** is on the host at **`http://localhost:8001`** (e.g. `aws dynamodb list-tables --endpoint-url http://localhost:8001`). Create the weather cache table with the one-off command above or **`make ensure-weather-cache-table`** on the host (see **Weather cache table**).

---

### Option C — Local Lambda emulation via SAM

Tests the exact Lambda packaging and handler before deploying to AWS.

**Prerequisites:** [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html), Docker

```bash
cd backend
cp env.json.example env.json   # fill in OPENWEATHER_API_KEY
make local                     # runs: sam build && sam local start-api
```

API available at `http://localhost:3000`.

> `env.json` is gitignored — it holds your plaintext key for local use only.

Set `WEATHER_CACHE_TABLE` in `env.json` to the name of an existing table (for example the `climbing-conditions-weather-dev` table from a deployed stack, or a local table if you point `AWS_ENDPOINT_URL_DYNAMODB` at DynamoDB Local on the host).

---

## Deploying to AWS

The stack is defined in `template.yaml` (AWS SAM). It creates:
- A Python 3.12 Lambda function
- An HTTP API Gateway (v2) forwarding all routes to the Lambda (no stage prefix — `$default` stage)
- A DynamoDB table `climbing-conditions-weather-${Stage}` (pay-per-request, TTL on attribute `ttl`) for caching OpenWeather responses per geohash cell
- An IAM policy granting the Lambda read access to SSM Parameter Store, plus `GetItem` / `BatchGetItem` / `PutItem` on that table
- The API key is fetched from SSM at Lambda cold-start and never stored in plaintext

### Prerequisites

- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- Docker or Podman (required for `--use-container` build — see note below)
- AWS CLI configured with the target account

> **No local Python 3.12 required.** SAM builds inside a container (`--use-container`) so the host Python version doesn't matter.

> **Using Podman instead of Docker?** Export the socket before running any `sam` command:
> ```bash
> export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
> ```

### 1. Store the API key in SSM

The key is stored as a `SecureString` and fetched by the Lambda at runtime — it never appears in plaintext in the AWS console.

```bash
aws ssm put-parameter \
  --name /climbing-conditions/openweather-api-key \
  --value "YOUR_KEY" \
  --type SecureString \
  --profile <your-aws-profile>
```

### 2. First-time deploy

```bash
cd backend
sam build --use-container
sam deploy \
  --stack-name climbing-conditions-api \
  --region eu-west-1 \
  --capabilities CAPABILITY_IAM \
  --resolve-s3 \
  --profile <your-aws-profile> \
  --parameter-overrides Stage=prod \
  --guided
```

SAM will prompt for confirmation and save the settings to `samconfig.toml` (gitignored).

### 3. Subsequent deploys

```bash
cd backend
sam build --use-container && sam deploy --profile <your-aws-profile>
```

### 4. Find the API URL

After a successful deploy, SAM prints the `ApiUrl` output. You can also retrieve it any time:

```bash
aws cloudformation describe-stacks \
  --stack-name climbing-conditions-api \
  --region eu-west-1 \
  --profile <your-aws-profile> \
  --query "Stacks[0].Outputs"
```

The URL has **no stage prefix** (the stack uses the `$default` stage):

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://<api-id>.execute-api.<region>.amazonaws.com
```

---

## Makefile targets

```
make dev            Plain Python uvicorn with hot-reload (port 8000)
make ensure-weather-cache-table   Create DynamoDB Local table from .env (one-time / idempotent)
make local          SAM build (--use-container) + local Lambda emulation (port 3000)
make build          sam build --use-container — packages deps into .aws-sam/
make deploy-guided  First-time interactive SAM deploy
make deploy         Subsequent SAM deploys using samconfig.toml
make package        Manual zip build (no SAM required)
make test           Run pytest
make clean          Remove .aws-sam/, deployment zips
```

> The `build`, `deploy`, and `local` targets all use `--use-container`. If you use Podman, set `DOCKER_HOST` first (see deploy instructions above).

---

## Project structure

```
backend/
├── main.py                  # FastAPI app, CORS + logging middleware
├── lambda_function.py       # Lambda entrypoint (Mangum ASGI adapter)
├── weather_cache_table_setup.py  # DynamoDB table ensure (local endpoint / Lambda describe)
├── routers/
│   ├── weather.py           # GET /api/weather — proxies OpenWeatherMap
│   └── crags.py             # GET /api/crags — local JSON catalog + bbox
├── services/
│   ├── weather_resolution_service.py  # Cell weather: Dynamo cache + OWM (§4)
│   └── crag_service.py      # Country bbox overlap, list crags in bbox
├── data/
│   ├── crag_country_bboxes.json
│   └── crags/               # e.g. be.json — one file per ISO country code
├── tests/                   # pytest
├── template.yaml            # AWS SAM template (Lambda + API Gateway)
├── Makefile                 # Dev, build, and deploy shortcuts
├── Dockerfile               # Container image (for Docker Compose / ECS)
├── docker-compose.yml       # backend + dynamodb-local (run from this directory)
├── requirements.txt         # All deps incl. uvicorn (local dev)
├── requirements-lambda.txt  # Production deps only (no uvicorn)
├── .env.example             # Local env template — copy to .env
├── env.json.example         # SAM local env template — copy to env.json
└── .gitignore
```
