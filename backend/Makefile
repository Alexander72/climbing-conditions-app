.PHONY: dev build deploy deploy-guided local package test clean ensure-weather-cache-table

# Always resolve paths relative to this Makefile's directory.
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
COMPOSE_FILE := $(ROOT_DIR)/docker-compose.yml

# ── Local development ────────────────────────────────────────────────────────

# Fastest iteration: plain Python with hot-reload
dev:
	uvicorn main:app --reload --host 0.0.0.0 --port 8000

# One-time (or idempotent) DynamoDB Local table for WEATHER_CACHE_TABLE — loads .env
ensure-weather-cache-table:
	@cd "$(ROOT_DIR)" && ( \
		if python3 -c "import boto3" >/dev/null 2>&1; then \
			echo "Using local python3 to create weather cache table"; \
			PYTHONPATH=. python3 weather_cache_table_setup.py; \
		else \
			echo "Local python3 missing boto3, trying backend container"; \
			if docker compose version >/dev/null 2>&1; then \
				docker compose -f "$(COMPOSE_FILE)" exec backend python3 weather_cache_table_setup.py; \
			else \
				docker-compose -f "$(COMPOSE_FILE)" exec backend python3 weather_cache_table_setup.py; \
			fi; \
		fi \
	)

# Local Lambda emulation via SAM (requires sam CLI and env.json)
local: build
	sam local start-api --env-vars env.json --port 3000

# ── Build & deploy ───────────────────────────────────────────────────────────

# Package the Lambda using SAM (output goes to .aws-sam/)
build:
	sam build --use-container

# First-time deploy — walks through guided setup and saves samconfig.toml
deploy-guided:
	sam build --use-container
	sam deploy --guided

# Subsequent deploys using saved samconfig.toml
deploy:
	sam build --use-container
	sam deploy

# ── Fallback: manual zip package (no SAM required) ───────────────────────────
# Installs dependencies into a local dir and zips everything together.
package:
	cd "$(ROOT_DIR)" && rm -rf dist && mkdir dist
	cd "$(ROOT_DIR)" && pip3 install -r requirements-lambda.txt --target dist/
	cd "$(ROOT_DIR)" && cp -r *.py routers services data dist/
	cd "$(ROOT_DIR)/dist" && zip -r ../deployment_package.zip . && cd ..
	cd "$(ROOT_DIR)" && rm -rf dist
	@echo "Created deployment_package.zip"

# ── Testing ──────────────────────────────────────────────────────────────────
test:
	cd "$(ROOT_DIR)" && PYTHONPATH=. pytest tests/

# ── Cleanup ──────────────────────────────────────────────────────────────────
clean:
	cd "$(ROOT_DIR)" && rm -rf .aws-sam dist deployment_package.zip
