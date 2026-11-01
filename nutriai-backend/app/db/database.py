import logging
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.core.config import settings

logger = logging.getLogger("nutriai.db")


def _prepare_sqlite_url(url: str) -> str:
    """
    Ensure SQLite parent directory exists and is writable.
    Render fails with 'unable to open database file' when /data is missing
    (no disk mounted). Fall back to /tmp for pitch demos if needed.
    """
    if not url.startswith("sqlite"):
        return url

    # sqlite:////data/x.db → /data/x.db ; sqlite:///./x.db → ./x.db
    db_path = Path(url.removeprefix("sqlite:///"))

    try:
        db_path.parent.mkdir(parents=True, exist_ok=True)
        probe = db_path.parent / ".nutriai_write_probe"
        probe.write_text("ok")
        probe.unlink(missing_ok=True)
        return url
    except OSError as exc:
        fallback = Path("/tmp/nutriai.db")
        logger.warning(
            "SQLite path %s not writable (%s). Falling back to %s "
            "(ephemeral — add a Render disk at /data for persistence).",
            db_path,
            exc,
            fallback,
        )
        return f"sqlite:///{fallback}"


DATABASE_URL = _prepare_sqlite_url(settings.DATABASE_URL)

connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    from app.db import models  # noqa: F401
    from sqlalchemy import inspect, text

    Base.metadata.create_all(bind=engine)

    # Lightweight SQLite column add for existing local DBs
    if DATABASE_URL.startswith("sqlite"):
        inspector = inspect(engine)
        if "users" in inspector.get_table_names():
            cols = {c["name"] for c in inspector.get_columns("users")}
            if "password_hash" not in cols:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255)"))
            if "role" not in cols:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN role VARCHAR(30) DEFAULT 'user'"))
            if "is_active" not in cols:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT 1"))
