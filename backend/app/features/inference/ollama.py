"""Finding an Ollama install already running on this machine.

Ollama is the runtime most people who have one at all will have, and it always listens on
the same loopback port. Probing that one address lets settings offer "use the Ollama you
already have" without asking the user for a URL they may not know.
"""

from app.features.inference.client import HttpInferenceClient

#: Where Ollama listens unless its user has moved it. Loopback only: detection never
#: reaches past this machine.
OLLAMA_BASE_URL = "http://127.0.0.1:11434/v1"


def ollama_client() -> HttpInferenceClient:
    """The client the detection probe speaks through."""
    return HttpInferenceClient(OLLAMA_BASE_URL)
