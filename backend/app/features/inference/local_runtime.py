"""The process-wide installer and supervisor of the downloaded runtime.

One data dir holds one runtime and one server serves it, whichever user is signed in, so
both are singletons; each is a FastAPI dependency so tests replace it.
"""

from functools import lru_cache

from app.core.config import get_settings
from app.features.inference.runtime_install import RuntimeInstaller
from app.features.inference.runtime_manifest import runtime_build
from app.features.inference.runtime_process import ManagedRuntime


@lru_cache
def get_runtime_installer() -> RuntimeInstaller:
    """The installer for `<data dir>/runtime`."""
    return RuntimeInstaller(get_settings().data_dir / "runtime", runtime_build())


@lru_cache
def get_managed_runtime() -> ManagedRuntime:
    """The supervisor of the server the installer put on disk."""
    return ManagedRuntime(
        get_runtime_installer(), get_settings().data_dir / "logs" / "llama-server.log"
    )


def stop_managed_runtime() -> None:
    """Stop the server at shutdown, without creating a supervisor nobody used."""
    if get_managed_runtime.cache_info().currsize:
        get_managed_runtime().stop()
