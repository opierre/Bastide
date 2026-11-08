"""Shared WebSocket conventions: close codes, and how an endpoint declares what it sends.

OpenAPI has no notion of a WebSocket, so `scripts/api_doc.py` can't read a socket's messages
off the schema the way it reads a route's response model. An endpoint names them instead with
`sends(...)`, and the generator documents those Pydantic models.
"""

from collections.abc import Callable
from typing import Any

from pydantic import BaseModel

#: The socket was opened without a valid ``Authorization: Bearer`` token — the WebSocket
#: counterpart of HTTP 401. In the 4000–4999 range the protocol leaves to applications.
CLOSE_UNAUTHENTICATED = 4401

#: The connection lacked the launch's session token (policy violation, refused before accept).
CLOSE_POLICY_VIOLATION = 1008

_MESSAGES_ATTRIBUTE = "__server_messages__"


def sends[F: Callable[..., Any]](*models: type[BaseModel]) -> Callable[[F], F]:
    """Declare the message models a WebSocket endpoint sends, for the API reference."""

    def decorate(endpoint: F) -> F:
        setattr(endpoint, _MESSAGES_ATTRIBUTE, models)
        return endpoint

    return decorate


def sent_messages(endpoint: Callable[..., Any]) -> tuple[type[BaseModel], ...]:
    """The models ``endpoint`` declared with `sends`, or none."""
    return getattr(endpoint, _MESSAGES_ATTRIBUTE, ())
