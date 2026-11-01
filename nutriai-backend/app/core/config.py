from __future__ import annotations

import json
from typing import Any, List, Union

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

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

    # CORS — accepts JSON list OR comma-separated string from Render env
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5173",
        "http://127.0.0.1:8000",
        "http://localhost:4200",
        "https://nutriai-pitch-demo.web.app",
        "https://nutriai-pitch-demo.firebaseapp.com",
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

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, v: Any) -> List[str]:
        if v is None or v == "":
            return []
        if isinstance(v, list):
            return [str(x).strip() for x in v if str(x).strip()]
        if isinstance(v, str):
            s = v.strip()
            if s.startswith("["):
                try:
                    parsed = json.loads(s)
                    if isinstance(parsed, list):
                        return [str(x).strip() for x in parsed if str(x).strip()]
                except json.JSONDecodeError:
                    pass
            return [p.strip() for p in s.split(",") if p.strip()]
        return [str(v).strip()]


settings = Settings()
