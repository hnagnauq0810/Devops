from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_read_root_returns_success_message() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {"message": "FastAPI DevOps Pipeline is running"}


def test_health_check_returns_ok() -> None:
    response = client.get("/health")
    body = response.json()

    assert response.status_code == 200
    assert body["status"] == "ok"
    assert body["service"] == "fastapi-devops-pipeline"
    assert "checked_at" in body


def test_create_item_valid_payload() -> None:
    response = client.post("/items", json={"id": 1, "name": "Book", "price": 9.99})

    assert response.status_code == 200
    assert response.json()["message"] == "Item created successfully"
    assert response.json()["item"]["name"] == "Book"


def test_create_item_rejects_invalid_price() -> None:
    response = client.post("/items", json={"id": 1, "name": "Book", "price": -1})

    assert response.status_code == 422
