"""Health check response."""

from pydantic import BaseModel


class HealthRead(BaseModel):
    """The sidecar is up, and which build is answering."""

    status: str
    version: str
