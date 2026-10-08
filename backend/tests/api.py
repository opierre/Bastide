"""Acting as a registered user in API tests."""

from dataclasses import dataclass

from fastapi.testclient import TestClient

PASSWORD = "correct-horse-battery-staple"


@dataclass(frozen=True, slots=True)
class RegisteredUser:
    """The header every request of a registered user carries, and the id their rows belong to."""

    headers: dict[str, str]
    user_id: str


def register_user(
    client: TestClient, email: str = "amelie@example.com", currency: str = "eur"
) -> RegisteredUser:
    """Register a user through the API and return their auth header and id."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": PASSWORD,
            # Display names are unique usernames: derive one per email.
            "display_name": email.split("@")[0],
            "locale": "fr",
            "currency": currency,
        },
    )
    assert response.status_code == 201, response.json()
    body = response.json()
    return RegisteredUser(
        headers={"Authorization": f"Bearer {body['token']}"}, user_id=body["user"]["id"]
    )


def register(
    client: TestClient, email: str = "amelie@example.com", currency: str = "eur"
) -> dict[str, str]:
    """Register a user through the API and return the auth header their requests carry."""
    return register_user(client, email, currency).headers
