# P2-04 — Stage-2 categorization service
Scope: backend
Depends on: P2-03
Skills: ai-categorization, fastapi-backend, i18n-l10n, testing
PROJECT.md: §7

## Objective
The pure decision layer of AI categorization: build a compact prompt from a batch of unmatched
transactions plus the category list, call the inference client, parse the reply defensively, and
apply the confidence threshold. No DB writes, no orchestration — those are P2-05.

## Files
- `backend/app/features/categorization/{prompt,parser,service}.py`
- `backend/app/features/categorization/schemas.py` — `Suggestion`, `SuggestionOutcome`
- `backend/tests/features/categorization/{test_prompt,test_parser,test_service}.py`

## Steps
1. `prompt.py` — build messages from: the user's category list (id + localized name + kind, leaf
   categories only), a few-shot set of 3–5 French *and* English examples, and the batch's rows
   (`description_clean`, `merchant`, amount sign, absolute amount). Keep it compact: no raw
   `description_raw`, no memo, no account or user identifiers. Emit the JSON schema for the
   expected reply so the client can request structured output.
2. Reply shape, one object per input row, correlated by the row's index in the batch:
   `{"index": int, "category_id": str, "confidence": float}`. Index rather than transaction id —
   sending UUIDs costs tokens the model has no use for and invites it to hallucinate one.
3. `parser.py` — parse defensively. Every one of these is a **deferral, never an exception**:
   non-JSON output, JSON that isn't the expected shape, a `category_id` not in the offered list,
   a confidence outside `[0,1]` or non-numeric, a missing index, a duplicate index. Tolerate
   prose or code fences around the JSON. Log at debug, count, move on.
4. `service.py` — `categorize_batch(rows, categories, settings) -> list[SuggestionOutcome]`,
   where each outcome is `assigned` (confidence ≥ threshold), `deferred` (below threshold or
   unparseable), or `failed` (the runtime itself errored for that batch). Threshold comes from
   `user_settings`, never a constant.
5. Batch size is a module constant (start at 20) with a comment on the trade-off: bigger batches
   amortise the category list across more rows, but a small model's accuracy and index-tracking
   both degrade as the batch grows.
6. Pure and synchronous with the client injected — no session, no run row, no background task.

## Acceptance
- A confident, well-formed reply assigns the category with `source=model`, the confidence stored,
  and `needs_review=false` in the returned outcome.
- Below-threshold suggestions defer and carry **no** category.
- Garbage, truncated, fenced, hallucinated-id, and out-of-range replies all defer without raising.
- A batch the runtime errored on returns `failed` outcomes, not a raised exception.
- The prompt contains no raw description, memo, account id, or user id.
- `ruff` + `ty` clean.

## Tests
- `test_prompt.py`: category list and few-shot present; excluded fields absent; French and
  English rows both render.
- `test_parser.py`: table-driven over every malformed case in step 3 → all deferred, none raise;
  well-formed reply parses; fenced JSON parses.
- `test_service.py` (client mocked): threshold boundary (exactly at threshold assigns);
  threshold read from settings, not hardcoded; `InferenceUnavailable` → all `failed`;
  mixed batch → correct per-row outcomes.

## Commits
- `feat(categorization): add prompt builder for stage-2 suggestions`
- `feat(categorization): add defensive suggestion parser`
- `feat(categorization): add confidence-threshold suggestion service`
