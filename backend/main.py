from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import weather, crags

app = FastAPI(title="Climbing Conditions API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok"}


app.include_router(weather.router, prefix="/api")
app.include_router(crags.router, prefix="/api")
