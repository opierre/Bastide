# 01 — Tool wrappers

## Design Prompts — How to use
Each panel file (02–15; 10–11 Phase 2, 12–15 Phase 3) is self-contained: pair it with 00-shared-design-block.md and it fully specifies one panel. Iterate against the mockup canvas by frame name (e.g. "04-Dashboard — empty"); regenerate the matching panel file only.

## Priority order
00 shared block → 04 dashboard → 07 transactions → 06 imports → 05 accounts → 08 categories-rules → 02/03 auth → 09 settings. Dashboard and Transactions carry the fr+en variants and most component states; build them first.

## Claude Design wrapper
Prompt shape used for this set: paste 00-shared-design-block.md verbatim as binding tokens, then one panel file, then the instruction "render every state listed under States to show as a separate 1440×900 frame named NN-Panel — variant; French first, English only where listed". Components must be referenced by their §Components names.

## Phase 3 wrapper
The Phase 3 « Patrimoine » panels (12 Crédits · 13 Impôts · 14 Simulateur · 15 Synthèse) have their
own ready-to-paste prompt: `PROMPT-phase3.md`. It carries the invariants, the shared mock data, a
brief and a state list per panel, and the contract for the description files the run must produce
(`12-credits.md` … `15-synthese.md` plus a Phase 3 additions paragraph for `00`). Regenerating one
panel means re-pasting `00-shared-design-block.md` + `PROJECT.md` §15–§18 + that panel's brief
only, after re-reading the amendment paragraphs below. Stage 1 and Stage 2 of that prompt were run on 12/09/2026: frames live in `FinStride Phase 3 Mockups.dc.html`, the description files `12-credits.md` … `15-synthese.md` are written, and `00` carries the Phase 3 additions paragraph. Review decisions recorded there: total estimé 4 419,99 € (components account exactly), capacity derived from the simulation's own terms, Synthèse = "Net worth" in EN, invented comparison/series/charges figures marked « à fournir ».

## Amendments survive regeneration
The mockup is the source of truth *until a panel ships*. Once built, **the Flutter code is the source of truth for that panel's tokens and behaviour**, and the amendment paragraphs in these files record why the build diverged from what was drawn. A regenerated frame that quietly undoes one — the Manrope→Geist swap, the #0A0F15 field tone, the SavingsRateCard tint, the spin token, the flexible TransactionRow label — is a regression in the file, not a design decision, because the shipped app does not change when a mockup is re-rendered. When regenerating, re-read the amendment paragraphs and carry them forward; when transcribing a new frame, check it against `frontend/lib/core/theme/tokens.dart` before recording a token that contradicts it.

## Notes
Where the mockup deviates from earlier specs for a panel not yet built, these files describe the drawn design. Frames are static states, not flows; interactions are described in each file's Notes.