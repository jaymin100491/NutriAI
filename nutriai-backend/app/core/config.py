from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    # Application
    APP_NAME: str = "NutriAI API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    ENVIRONMENT: str = "development"
    DEMO_MODE: bool = True
    # Seed ~55 illustrative cohort users (labs, plans, tracking, retest-ready orders)
    SEED_DEMO_COHORT: bool = True

    # API
    API_V1_PREFIX: str = "/api/v1"
    SECRET_KEY: str = "dev-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480

    # Database — SQLite for local dev, PostgreSQL for staging/production
    DATABASE_URL: str = "sqlite:///./nutriai.db"

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5173",
        "http://127.0.0.1:8000",
        "http://localhost:4200",
    ]

    # AI APIs — when set, weekly plans generate meals on the fly for any diet/cuisine
    ANTHROPIC_API_KEY: str = ""
    OPENAI_API_KEY: str = ""
    AI_MEAL_GENERATION: bool = True  # prefer live AI chef; catalog is fallback

    # Legacy Labcorp/Okta fields kept optional for old code paths — unused in open-market demo
    LABCORP_PORTAL_API_URL: str = ""
    LABCORP_USE_MOCK: bool = True
    OKTA_ISSUER: str = ""
    OKTA_CLIENT_ID: str = ""
    OKTA_REDIRECT_URI: str = ""
    OKTA_SCOPES: str = "openid profile email"

    # Health records — paste import today; auto-sync later
    MYCHART_USE_MOCK: bool = True
    DEFAULT_HEALTH_SYSTEM: str = "health_records"

    # Token encryption at rest (Fernet key — generate for production)
    TOKEN_ENCRYPTION_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
