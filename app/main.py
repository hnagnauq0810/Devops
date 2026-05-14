from datetime import UTC, datetime
from typing import Literal

from fastapi import FastAPI
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: str = "fastapi-devops-pipeline"
    version: str = Field(default="1.0.0")
    checked_at: str


class Item(BaseModel):
    id: int = Field(gt=0)
    name: str = Field(min_length=1, max_length=100)
    price: float = Field(ge=0)


app = FastAPI(
    title="DevOps Pipeline for FastAPI",
    description="FastAPI application used for a Docker, SonarQube, and CI/CD final exam project.",
    version="1.0.0",
)


@app.get("/", tags=["root"])
def read_root() -> dict[str, str]:
    return {"message": "FastAPI DevOps Pipeline is running"}


@app.get("/health", response_model=HealthResponse, tags=["health"])
def health_check() -> HealthResponse:
    return HealthResponse(checked_at=datetime.now(UTC).isoformat())


@app.post("/items", tags=["items"])
def create_item(item: Item) -> dict[str, Item | str]:
    return {"message": "Item created successfully", "item": item}
