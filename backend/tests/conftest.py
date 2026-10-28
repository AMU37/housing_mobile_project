from __future__ import annotations

import os
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parents[1]
TEST_DATA = BACKEND_DIR / "test_data.json"

os.environ.setdefault("ENVIRONMENT", "development")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pytest-only-32-characters")
os.environ["DATA_FILE"] = TEST_DATA.name
os.environ.setdefault("SEED_FILE", "seed.json")
os.environ["DATABASE_URL"] = ""
os.environ["FORCE_PASSWORD_CHANGE"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture(scope="session")
def client():
    if TEST_DATA.exists():
        TEST_DATA.unlink()
    with TestClient(app) as test_client:
        yield test_client
    if TEST_DATA.exists():
        TEST_DATA.unlink()


@pytest.fixture(scope="session")
def admin_token(client: TestClient) -> str:
    response = client.post("/api/auth/login", json={"username": "admin", "password": "123456"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body.get("token") == body.get("access_token")
    return body["access_token"]


@pytest.fixture(scope="session")
def admin_headers(admin_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {admin_token}"}
