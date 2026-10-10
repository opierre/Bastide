"""Response schemas for the inference feature."""

from typing import Literal

from pydantic import BaseModel, ConfigDict


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


class RuntimeStatus(BaseModel):
    """The opt-in local runtime: whether it is on disk, and how far its download got.

    `total_bytes` is what is still missing, so before a download starts it is the size to
    show the user; `downloaded_bytes` counts what of it is already on disk. `error` says why
    the runtime is not usable, as a code the frontend localizes: why the last download
    stopped short, or `server_removed` when something (antivirus, in practice) deleted the
    server after it was installed. Downloading again reinstalls it.
    """

    model_config = ConfigDict(protected_namespaces=())

    state: Literal["unsupported", "absent", "downloading", "installed", "failed"]
    downloaded_bytes: int
    total_bytes: int
    error: Literal["network", "hash_mismatch", "disk_full", "extract", "server_removed"] | None = (
        None
    )
    #: The model tag the runtime serves its model under, for settings to store.
    model_tag: str
    #: Whether the server is up. It starts on the first request that needs a model.
    running: bool = False
