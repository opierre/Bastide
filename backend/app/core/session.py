"""The per-launch session token that keeps other local processes off the API.

Binding to loopback keeps the network out, not the machine: any process, or any page served
from `localhost`, could otherwise call the finance API. The desktop app generates a random
token on every launch, hands it to the sidecar in `BASTIDE_SESSION_TOKEN`, and sends it back
on every request.

It travels in its own header because `Authorization` already carries the user's login token.
"""

import hmac

from fastapi.responses import JSONResponse
from starlette.datastructures import Headers
from starlette.types import ASGIApp, Receive, Scope, Send

SESSION_TOKEN_HEADER = "X-Bastide-Session"


class SessionTokenMiddleware:
    """Reject every request that doesn't carry the launch's session token."""

    def __init__(self, app: ASGIApp, token: str) -> None:
        self.app = app
        self._token = token.encode()

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "lifespan":
            await self.app(scope, receive, send)
            return
        supplied = Headers(scope=scope).get(SESSION_TOKEN_HEADER, "").encode()
        # Constant-time, so response timing doesn't reveal how much of a guess was right.
        if hmac.compare_digest(supplied, self._token):
            await self.app(scope, receive, send)
            return
        response = JSONResponse(
            status_code=401,
            content={
                "error": {
                    "code": "SESSION_TOKEN_INVALID",
                    "message": "Missing or invalid session token.",
                }
            },
        )
        await response(scope, receive, send)
