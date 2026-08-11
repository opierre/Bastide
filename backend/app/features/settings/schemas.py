"""Request/response schemas for the settings feature."""

import ipaddress
from typing import Annotated
from urllib.parse import urlparse

from pydantic import AfterValidator, BaseModel, ConfigDict, Field


def _validate_loopback_url(value: str) -> str:
    """Accept only `http(s)` URLs pointing at a loopback host.

    The sidecar is loopback-only by design (`PROJECT.md` §3/§8). `inference_base_url` is
    the one setting that decides where transaction descriptions get sent, so a value
    naming a remote host would quietly move the user's data off their machine — that is
    a rejected value, not a supported configuration.

    Raises:
        ValueError: the URL is not `http(s)`, has no host, or the host is not loopback.
    """
    parsed = urlparse(value)
    if parsed.scheme not in ("http", "https"):
        raise ValueError("inference_base_url must use http or https.")

    host = parsed.hostname
    if not host:
        raise ValueError("inference_base_url must include a host.")
    if host == "localhost":
        return value

    try:
        address = ipaddress.ip_address(host)
    except ValueError as exc:
        # A name other than `localhost` resolves wherever DNS says — including off-machine.
        raise ValueError("inference_base_url must point at a loopback host.") from exc
    if not address.is_loopback:
        raise ValueError("inference_base_url must point at a loopback host.")
    return value


InferenceBaseUrl = Annotated[
    str, Field(min_length=1, max_length=255), AfterValidator(_validate_loopback_url)
]
ConfidenceThreshold = Annotated[float, Field(ge=0, le=1)]


class SettingsUpdate(BaseModel):
    """Patch payload; omitted fields keep their stored value."""

    # `model_tag` is the runtime's model identifier, not a Pydantic model attribute —
    # clearing the protected namespace keeps the field name the contract asks for.
    model_config = ConfigDict(protected_namespaces=())

    ai_enabled: bool | None = None
    inference_base_url: InferenceBaseUrl | None = None
    model_tag: str | None = Field(default=None, max_length=255)
    confidence_threshold: ConfidenceThreshold | None = None


class SettingsRead(BaseModel):
    """A user's settings as returned by the API."""

    model_config = ConfigDict(protected_namespaces=())

    ai_enabled: bool
    inference_base_url: str
    model_tag: str | None
    confidence_threshold: float
