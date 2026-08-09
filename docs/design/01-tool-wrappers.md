# 01 — Tool wrappers

## Design Prompts — How to use
Each panel file (02–09) is self-contained: pair it with 00-shared-design-block.md and it fully specifies one panel. Iterate against the mockup canvas by frame name (e.g. "04-Dashboard — empty"); regenerate the matching panel file only.

## Priority order
00 shared block → 04 dashboard → 07 transactions → 06 imports → 05 accounts → 08 categories-rules → 02/03 auth → 09 settings. Dashboard and Transactions carry the fr+en variants and most component states; build them first.

## Claude Design wrapper
Prompt shape used for this set: paste 00-shared-design-block.md verbatim as binding tokens, then one panel file, then the instruction "render every state listed under States to show as a separate 1440×900 frame named NN-Panel — variant; French first, English only where listed". Components must be referenced by their §Components names.

## Amendments survive regeneration
The mockup is the source of truth *until a panel ships*. Once built, **the Flutter code is the source of truth for that panel's tokens and behaviour**, and the amendment paragraphs in these files record why the build diverged from what was drawn. A regenerated frame that quietly undoes one — the Manrope→Geist swap, the #0A0F15 field tone, the SavingsRateCard tint, the spin token, the flexible TransactionRow label — is a regression in the file, not a design decision, because the shipped app does not change when a mockup is re-rendered. When regenerating, re-read the amendment paragraphs and carry them forward; when transcribing a new frame, check it against `frontend/lib/core/theme/tokens.dart` before recording a token that contradicts it.

## Notes
Where the mockup deviates from earlier specs for a panel not yet built, these files describe the drawn design. Frames are static states, not flows; interactions are described in each file's Notes.