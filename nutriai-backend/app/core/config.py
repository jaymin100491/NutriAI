from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    # Application
    APP_NAME: str = "NutriAI API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    ENVIRONMENT: str = "development"
    DEMO_MODE: bool = False

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
        "https://patient-local.labcorp.com:4200",
        "http://patient-local.labcorp.com:4200",
    ]

    # AI APIs
    ANTHROPIC_API_KEY: str = ""
    OPENAI_API_KEY: str = ""

    # Labcorp Patient Portal QA (same as patient-website-ui environment.qa.json)
    LABCORP_PORTAL_API_URL: str = "https://portal-api.patient-qa.dev.cws.labcorp.com"
    LABCORP_USE_MOCK: bool = False

    # Okta QA — redirect must be https://patient-local.labcorp.com:4200/callback
    OKTA_ISSUER: str = "https://login-patientqa.labcorp.com/oauth2/default"
    OKTA_CLIENT_ID: str = "0oa1ec6lfv1VzTPcy0h8"
    OKTA_REDIRECT_URI: str = "https://patient-local.labcorp.com:4200/callback"
    OKTA_SCOPES: str = "openid profile email"

    # MyChart — deferred
    MYCHART_USE_MOCK: bool = True
    DEFAULT_HEALTH_SYSTEM: str = "health_records"

    # Token encryption at rest (Fernet key — generate for production)
    TOKEN_ENCRYPTION_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
