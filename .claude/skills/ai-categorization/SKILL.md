---
name: ai-categorization
description: Use for transaction categorization and the AI insights feature in the finstride. Covers the deterministic rule engine (Phase 1) and the Phase 2 Ollama SLM layer — the rules→model→confidence-deferral pattern, the human review/confirm queue, learning corrections back into rules, model selection (Gemma 4 default, finance-tuned 8B for insights), graceful degradation when Ollama is absent, and full mocking of the model in tests.
---

# AI Categorization

Assigns categories to transactions cheaply, deterministically where possible, with the model
only on the uncertain remainder and a human in the loop. Source of truth: `PROJECT.md` §7.

## Two-stage pipeline

```
transaction → [1] rule engine → matched? → done (source=rule, needs_review=false)
                               → no match → [2] SLM (Phase 2) → confident? → done (source=model)
                                                              → uncertain → review queue (needs_review=true)
```

### Stage 1 — rule engine (Phase 1, always on, deterministic)

- Evaluate enabled `categorization_rules` ordered by `priority` ascending; **first match wins**.
- Match types: `contains | equals | regex` on `description_clean`/`merchant`, `range` on amount.
- On match: set `category_id`, `categorization_source = rule`, `needs_review = false`.
- No match: `category_id = null`, `source = uncategorized`, `needs_review = true`.
- `POST /rules/apply` re-runs rules over existing rows but **never overrides** a transaction with
  `source = user`. User intent is sacred.

This stage handles the easy majority (recurring merchants, salary, known patterns) with zero
tokens and full reproducibility.

### Stage 2 — SLM via Ollama (Phase 2, optional)

- Only **unmatched** transactions reach the model. The prompt contains: the localized category
  list (id + name + kind), the transaction's `description_clean`/`merchant`/amount sign, and a
  small few-shot set. The model returns a `category_id` + a `confidence` in [0,1].
- If `confidence ≥ threshold` (default **0.80**, configurable in settings): assign,
  `source = model`, `confidence` stored, `needs_review = false`.
- Else: leave for the user, `needs_review = true`.
- Batch requests where possible; keep the prompt compact (token discipline). Constrain output to
  a strict JSON shape and parse defensively — a malformed model reply ⇒ treat as uncertain, never
  crash the import.

This is the small-model-with-deferral pattern: cheap model on the easy part, human on the rest.

## Human review queue

- Transactions with `needs_review = true` surface in a review UI: confirm the guess, or pick the
  correct category.
- A user correction sets `source = user` and may offer **"always categorize <pattern> as <cat>"**
  → creates a `categorization_rule`. The system thus learns cheaply and *deterministically*:
  next time, Stage 1 handles it with no model call. This is the primary mechanism that drives
  token usage down over time.

## Model selection

- **Default categorization model: Gemma 4 E4B** — small, ~4 GB RAM class, multilingual (incl.
  French), tool-capable, runs from GGUF in Ollama. Pick the size by detected hardware:
  E2B (low-end) / E4B (default sweet spot) / 26B MoE (capable machines). User-overridable.
- **Insights / advisory feature: a finance-tuned ~8B model** (e.g. the AGEFI/Dragon LLM Open
  Finance Initiative models, Llama-3.1/Qwen-3 based, strong fr+en financial vocabulary). The
  domain tuning helps with French financial terminology where a general small model is weaker.
  Also runs in Ollama, selectable in settings.
- Model names/tags are **config**, never hardcoded in logic. Settings exposes model choice and
  the confidence threshold.

## Graceful degradation (hard requirement)

The app must fully work with **no Ollama installed**. If the model endpoint is unreachable:
- Categorization runs **Stage 1 only**; unmatched rows stay `uncategorized / needs_review`.
- The UI shows a calm, optional "enable local AI for smarter categorization" affordance — never
  an error wall, never a blocked import.
- The insights feature is hidden/disabled, not broken.

## Insights feature

- Generates plain-language suggestions (spending trends, subscription creep, savings-rate
  nudges) from **aggregated local data**, in the user's language, via the finance-tuned model.
- Framed as guidance, not financial/tax advice; no guarantees. Keep prompts aggregate-only —
  don't ship raw transaction dumps to the model unnecessarily (privacy + tokens).

## Testing (model fully mocked)

- **Unit tests never call a live model.** Mock the Ollama client. Test: confident reply →
  assigned; low-confidence → review queue; malformed/garbage reply → treated as uncertain, no
  crash; Ollama unreachable → Stage-1-only path, import still succeeds.
- Test the learning loop: a user correction with "always" creates a rule that then matches in
  Stage 1 on the next run.
- Rule engine tests (Phase 1): priority ordering, first-match-wins, `source=user` never
  overridden, `range`/`regex` matching.
