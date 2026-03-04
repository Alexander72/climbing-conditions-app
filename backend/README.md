# Climbing Conditions — Backend API

A lightweight FastAPI service that proxies external APIs (OpenWeatherMap, OpenBeta) so the Flutter app never handles third-party credentials directly.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check — returns `{"status": "ok"}` |
| `GET` | `/api/weather?lat=&lon=` | Current weather + hourly history/forecast from OpenWeatherMap |
| `GET` | `/api/crags?region=Belgium` | Crag/area data from OpenBeta GraphQL |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (or [Podman](https://podman.io/) with `podman-compose`)
- An [OpenWeatherMap API key](https://openweathermap.org/api) (One Call API 3.0)

## Quick start

```bash
# 1. Create your local env file from the example
cp backend/.env.example backend/.env

# 2. Open backend/.env and set OPENWEATHER_API_KEY

# 3. Build and start the container (run from the repo root)
docker compose up --build
```

The API is now available at `http://localhost:8000`.

To run the Flutter app against it:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

## Environment variables

All variables are read from `backend/.env` (gitignored). Copy [`.env.example`](.env.example) to get started.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENWEATHER_API_KEY` | **Yes** | — | OpenWeatherMap API key |
| `OPENWEATHER_BASE_URL` | No | `https://api.openweathermap.org/data/3.0/onecall` | OWM endpoint (useful for testing) |
| `OPENBETA_HOST` | No | `https://api.openbeta.io` | OpenBeta base host |
| `BACKEND_PORT` | No | `8000` | Host port mapped in `docker-compose.yml` |

## Running without Docker

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # then fill in OPENWEATHER_API_KEY
uvicorn main:app --reload
```

## Project structure

```
backend/
├── main.py              # FastAPI app, CORS middleware, router registration
├── routers/
│   ├── weather.py       # GET /api/weather — proxies OpenWeatherMap
│   └── crags.py         # GET /api/crags  — proxies OpenBeta GraphQL
├── Dockerfile
├── requirements.txt
├── .env.example
└── .gitignore
```
