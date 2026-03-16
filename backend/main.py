import logging
import time
import traceback
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from routers import weather, crags

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("climbing-conditions-api")

app = FastAPI(title="Climbing Conditions API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    logger.info("Request start: %s %s", request.method, request.url)
    try:
        response = await call_next(request)
    except Exception:
        duration = time.time() - start
        logger.exception(
            "Unhandled exception after %.3fs: %s %s", duration, request.method, request.url
        )
        raise
    duration = time.time() - start
    logger.info(
        "Request end: %s %s -> %s (%.3fs)",
        request.method, request.url, response.status_code, duration,
    )
    return response


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.error(
        "Unhandled exception on %s %s:\n%s",
        request.method,
        request.url,
        traceback.format_exc(),
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error": type(exc).__name__,
            "message": str(exc),
        },
    )


@app.get("/health")
async def health():
    return {"status": "ok"}


app.include_router(weather.router, prefix="/api")
app.include_router(crags.router, prefix="/api")
