"""Business logic for probing the local inference runtime."""

from app.features.inference.client import InferenceClient, InferenceError
from app.features.inference.schemas import InferenceHealth


class InferenceService:
    """Reports on the runtime a user has configured, without ever failing because of it."""

    def __init__(self, client: InferenceClient) -> None:
        self._client = client

    async def health(self) -> InferenceHealth:
        """Probe the runtime and report what it offers.

        Raises nothing: an absent runtime is the expected default state, not an app error,
        so an unreachable probe returns `reachable=False` with the reason in `detail`.
        """
        try:
            models = await self._client.list_models()
        except InferenceError as exc:
            return InferenceHealth(reachable=False, models=[], detail=str(exc))
        return InferenceHealth(reachable=True, models=models)
