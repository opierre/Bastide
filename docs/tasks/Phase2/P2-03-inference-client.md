# P2-03 — Local inference client & health probe
Scope: backend
Depends on: P2-01
Skills: ai-categorization, fastapi-backend, testing
PROJECT.md: §3, §5b

## Objective
One narrow client for the local inference runtime, speaking the **OpenAI-compatible `/v1`**
surface that both `llama-server` (llama.cpp) and Ollama expose, plus a health endpoint the UI
uses to discover what's running. Nothing above this module may know which engine answered.

## Files
- `backend/app/features/inference/{__init__,client,schemas,service,router}.py`
- `backend/tests/features/inference/test_client.py`, `test_health.py`

## Contract slice
```
GET /api/v1/settings/inference/health → 200 {reachable: bool, models: [tag], detail?: str}
```

## Steps
1. `client.py` — an `InferenceClient` protocol/ABC with two operations:
   `list_models() -> list[str]` (`GET /v1/models`) and
   `complete(messages, *, model, response_format=None, timeout) -> str`
   (`POST /v1/chat/completions`, non-streaming). One HTTP implementation built from a
   `user_settings` row. **No runtime-specific endpoints** (`/api/tags`, `/api/generate`, …) —
   `PROJECT.md` §3 explains why the abstraction is the point.
2. Timeouts are mandatory and configurable (default: connect 2 s, read 120 s). A local model
   generating is slow; a local model *absent* fails instantly — the two must not share a budget.
3. Map failures onto a small typed error set — `InferenceUnavailable` (connect refused / DNS /
   timeout on connect), `InferenceTimeout` (read timeout), `InferenceProtocolError` (non-2xx or
   unparseable body). Callers branch on these, never on `httpx` exceptions.
4. `response_format` passes a JSON-schema structured-output request when supplied. Runtimes vary
   in support, so the client **must not** rely on it: if the runtime rejects the parameter,
   retry once without it. Constraining output is an optimisation; defensive parsing (P2-04) is
   the guarantee.
5. Health service: probe `list_models()` against the user's settings. Return
   `{reachable: false, detail}` **as a 200** — an absent runtime is the expected default state,
   not an app error (see the graceful-degradation section of the ai-categorization skill).
   Never let the probe hang the request: use the connect timeout only.
6. Router mounted under the settings prefix so the frontend has one settings surface.

## Acceptance
- Client speaks only `/v1/models` and `/v1/chat/completions`.
- Every network failure surfaces as one of the three typed errors — no raw client exception
  escapes the module.
- Health returns 200 with `reachable: false` when nothing is listening; 200 with the model list
  when something is.
- A runtime that rejects `response_format` still yields a completion (one retry without it).
- No live HTTP in tests. `ruff` + `ty` clean.

## Tests
- `test_client.py` (transport mocked): successful completion parsed; connection refused →
  `InferenceUnavailable`; read timeout → `InferenceTimeout`; 500 and malformed JSON body →
  `InferenceProtocolError`; `response_format` rejected → retried without it and succeeds.
- `test_health.py`: reachable → models listed; unreachable → 200 `reachable: false` with detail,
  and the response arrives without waiting out the read timeout.

## Commits
- `feat(inference): add OpenAI-compatible local runtime client`
- `feat(inference): add runtime health probe endpoint`
