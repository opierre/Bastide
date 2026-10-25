"""Shared fixtures for the net-worth tests."""

from datetime import date
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.features.networth.router import get_today

TODAY = date(2026, 5, 15)


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY
