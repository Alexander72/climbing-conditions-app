.PHONY: dev build deploy deploy-guided local package test clean

# ── Local development ────────────────────────────────────────────────────────

# Fastest iteration: plain Python with hot-reload
dev:
	uvicorn main:app --reload --host 0.0.0.0 --port 8000

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
	rm -rf dist && mkdir dist
	pip install -r requirements-lambda.txt --target dist/
	cp -r *.py routers dist/
	cd dist && zip -r ../deployment_package.zip . && cd ..
	rm -rf dist
	@echo "Created deployment_package.zip"

# ── Testing ──────────────────────────────────────────────────────────────────
test:
	pytest

# ── Cleanup ──────────────────────────────────────────────────────────────────
clean:
	rm -rf .aws-sam dist deployment_package.zip
