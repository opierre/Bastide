"""Tests for the text size preference."""

import pytest
from fastapi.testclient import TestClient

from tests.api import register

TEXT_SIZE_URL = "/api/v1/auth/me/text-size"


def test_a_new_user_gets_the_normal_text_size(client: TestClient) -> None:
    headers = register(client)

    me = client.get("/api/v1/auth/me", headers=headers).json()

    assert me["user"]["text_size"] == "normal"


@pytest.mark.parametrize("text_size", ["normal", "large", "xlarge"])
def test_the_text_size_is_saved_and_returned(client: TestClient, text_size: str) -> None:
    headers = register(client)

    response = client.put(TEXT_SIZE_URL, headers=headers, json={"text_size": text_size})

    assert response.status_code == 200
    assert response.json()["user"]["text_size"] == text_size
    me = client.get("/api/v1/auth/me", headers=headers).json()
    assert me["user"]["text_size"] == text_size


def test_the_text_size_belongs_to_its_user(client: TestClient) -> None:
    amelie = register(client, "amelie@example.com")
    bruno = register(client, "bruno@example.com")

    client.put(TEXT_SIZE_URL, headers=amelie, json={"text_size": "large"})

    me = client.get("/api/v1/auth/me", headers=bruno).json()
    assert me["user"]["text_size"] == "normal"


@pytest.mark.parametrize("text_size", ["small", "", "LARGE", 2])
def test_an_unknown_text_size_is_refused(client: TestClient, text_size: object) -> None:
    headers = register(client)

    response = client.put(TEXT_SIZE_URL, headers=headers, json={"text_size": text_size})

    assert response.status_code == 422


def test_setting_the_text_size_requires_auth(client: TestClient) -> None:
    assert client.put(TEXT_SIZE_URL, json={"text_size": "large"}).status_code == 401
