import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.db.database import init_db

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    init_db()
    yield


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] in ("healthy", "degraded")


def test_okta_authorize():
    response = client.get("/api/v1/auth/okta/authorize")
    assert response.status_code == 200
    data = response.json()
    assert "authorization_url" in data
    assert "login-patientqa.labcorp.com" in data["authorization_url"]
    assert data["redirect_uri"].endswith("/callback")


def test_demo_login_disabled_by_default():
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "1@1.com", "password": "test"},
    )
    assert response.status_code == 403
