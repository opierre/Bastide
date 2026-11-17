"""Tests for the theme preference."""

import pytest
from fastapi.testclient import TestClient

from tests.api import register

THEME_URL = "/api/v1/auth/me/theme"


def test_a_new_user_gets_the_dark_theme(client: TestClient) -> None:
    headers = register(client)

    me = client.get("/api/v1/auth/me", headers=headers).json()

    assert me["user"]["theme"] == "dark"


@pytest.mark.parametrize("theme", ["system", "dark", "light"])
def test_the_theme_is_saved_and_returned(client: TestClient, theme: str) -> None:
    headers = register(client)

    response = client.put(THEME_URL, headers=headers, json={"theme": theme})

    assert response.status_code == 200
    assert response.json()["user"]["theme"] == theme
    assert client.get("/api/v1/auth/me", headers=headers).json()["user"]["theme"] == theme


def test_the_theme_belongs_to_its_user(client: TestClient) -> None:
    amelie = register(client, "amelie@example.com")
    bruno = register(client, "bruno@example.com")

    client.put(THEME_URL, headers=amelie, json={"theme": "light"})

    assert client.get("/api/v1/auth/me", headers=bruno).json()["user"]["theme"] == "dark"


@pytest.mark.parametrize("theme", ["sepia", "", "DARK"])
def test_an_unknown_theme_is_refused(client: TestClient, theme: str) -> None:
    headers = register(client)

    response = client.put(THEME_URL, headers=headers, json={"theme": theme})

    assert response.status_code == 422


def test_setting_the_theme_requires_auth(client: TestClient) -> None:
    assert client.put(THEME_URL, json={"theme": "light"}).status_code == 401
