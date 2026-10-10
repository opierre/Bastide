"""Response schemas for the inference feature."""

from pydantic import BaseModel


class InferenceHealth(BaseModel):
    """What the settings UI needs to know about the local runtime.

    `reachable: false` is a normal, reportable state — the app works without a runtime —
    so this is always carried on a 200.
    """

    reachable: bool
    models: list[str] = []
    detail: str | None = None


class OllamaDetection(BaseModel):
    """Whether an Ollama install answers on its default loopback address.

    `found: false` is the common case and, like an unreachable runtime, travels on a 200.
    """

    found: bool
    base_url: str
    models: list[str] = []
