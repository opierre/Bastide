"""Business logic for probing the local inference runtime."""

from app.features.inference.client import InferenceClient, InferenceError
from app.features.inference.ollama import OLLAMA_BASE_URL
from app.features.inference.schemas import InferenceHealth, OllamaDetection


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


async def detect_ollama(client: InferenceClient) -> OllamaDetection:
    """Probe Ollama's default address and report what answered.

    Goes through the same `/v1/models` call as the health probe rather than an
    Ollama-specific endpoint, so "found" means "a runtime the app can use answers there",
    which is the only thing settings needs to know before offering it.

    Raises nothing: no Ollama is the expected state on most machines.
    """
    try:
        models = await client.list_models()
    except InferenceError:
        return OllamaDetection(found=False, base_url=OLLAMA_BASE_URL)
    return OllamaDetection(found=True, base_url=OLLAMA_BASE_URL, models=models)
