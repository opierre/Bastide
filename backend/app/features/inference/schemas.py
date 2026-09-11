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
