from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
import logging
import time

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.database import init_db

logging.basicConfig(level=logging.INFO if not settings.DEBUG else logging.DEBUG)
logger = logging.getLogger("nutriai")

app = FastAPI(
    title="NutriAI API",
    description="AI-Powered Personalized Dietitian — lab-result nutrition coaching",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS if not settings.DEBUG else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)


@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    response.headers["X-Process-Time"] = str(round(time.time() - start_time, 3))
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected error occurred",
                "details": str(exc) if settings.DEBUG else None,
            },
        },
    )


app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.on_event("startup")
async def startup():
    init_db()
    from app.services.recipe_catalog import reset_recipe_catalog

    reset_recipe_catalog()
    if settings.DEMO_MODE:
        from app.db.database import SessionLocal
        from app.db.seed_demo import seed_demo_workspace

        db = SessionLocal()
        try:
            seed_demo_workspace(db)
            logger.info("Demo workspace seeded (jaymin@nutriai.app)")
        finally:
            db.close()

    logger.info(
        "NutriAI started — env=%s mock_labs=%s demo_mode=%s",
        settings.ENVIRONMENT,
        settings.LABCORP_USE_MOCK,
        settings.DEMO_MODE,
    )


@app.get("/")
async def root():
    return {
        "message": "NutriAI API",
        "version": "2.0.0",
        "docs": "/api/docs",
        "environment": settings.ENVIRONMENT,
        "labcorp_mock": settings.LABCORP_USE_MOCK,
    }


@app.get("/health")
async def health_check():
    from app.db.database import engine

    db_ok = True
    try:
        with engine.connect() as conn:
            conn.exec_driver_sql("SELECT 1")
    except Exception:
        db_ok = False

    return {
        "status": "healthy" if db_ok else "degraded",
        "database": "connected" if db_ok else "error",
        "environment": settings.ENVIRONMENT,
        "version": "2.0.0",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=settings.DEBUG)
