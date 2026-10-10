"""Which client a user's settings call for: the runtime at their address, or the downloaded one."""

from app.features.inference.client import HttpInferenceClient, InferenceClient
from app.features.inference.local_runtime import get_managed_runtime
from app.features.inference.runtime_process import ManagedRuntimeClient
from app.features.settings.models import UserSettings


def client_from_settings(settings: UserSettings) -> InferenceClient:
    """Build the client for the runtime a user has chosen.

    The downloaded runtime is reached through a client that starts it first: its port is
    picked at each launch, so it has no address worth storing.
    """
    if settings.inference_runtime == "managed":
        return ManagedRuntimeClient(get_managed_runtime())
    return HttpInferenceClient(settings.inference_base_url)
