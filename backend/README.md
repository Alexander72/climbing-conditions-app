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
      "isSummaryOnly": true
    }
  ]
}
```

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENWEATHER_API_KEY` | **Yes** | — | OpenWeatherMap One Call API 3.0 key |
| `OPENWEATHER_BASE_URL` | No | `https://api.openweathermap.org/data/3.0/onecall` | OWM endpoint (override for testing) |
| `BACKEND_PORT` | No | `8000` | Host port mapped in `docker-compose.yml` |

---

## Local development

Three options — pick the one that suits your setup.

### Option A — Plain Python (fastest iteration)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # fill in OPENWEATHER_API_KEY
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
cp backend/.env.example backend/.env   # fill in OPENWEATHER_API_KEY
docker compose up --build
```

API available at `http://localhost:8000`.

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

---

## Deploying to AWS

The stack is defined in `template.yaml` (AWS SAM). It creates:
- A Python 3.12 Lambda function
- An HTTP API Gateway (v2) forwarding all routes to the Lambda (no stage prefix — `$default` stage)
- An IAM policy granting the Lambda read access to SSM Parameter Store
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
├── routers/
│   ├── weather.py           # GET /api/weather — proxies OpenWeatherMap
│   └── crags.py             # GET /api/crags — local JSON catalog + bbox
├── services/
│   └── crag_catalog.py      # Country bbox overlap, load crags/*.json
├── data/
│   ├── crag_country_bboxes.json
│   └── crags/               # e.g. be.json — one file per ISO country code
├── tests/                   # pytest
├── template.yaml            # AWS SAM template (Lambda + API Gateway)
├── Makefile                 # Dev, build, and deploy shortcuts
├── Dockerfile               # Container image (for Docker Compose / ECS)
├── requirements.txt         # All deps incl. uvicorn (local dev)
├── requirements-lambda.txt  # Production deps only (no uvicorn)
├── .env.example             # Local env template — copy to .env
├── env.json.example         # SAM local env template — copy to env.json
└── .gitignore
```
