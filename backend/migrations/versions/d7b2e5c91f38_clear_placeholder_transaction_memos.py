"""clear placeholder transaction memos

Revision ID: d7b2e5c91f38
Revises: c3f5a1d47e92
Create Date: 2026-08-09 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d7b2e5c91f38"
down_revision: str | Sequence[str] | None = "c3f5a1d47e92"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Every character banks use as a "no memo here" placeholder. Matching on the set rather
# than on "has no letter or digit" keeps this expressible in plain SQL, and the rows it
# leaves behind are re-cleaned by `canonical.clean_memo` on the next import anyway.
_PLACEHOLDERS = (".", "-", "*", "/", "..", "...", "--", "N/A")


def upgrade() -> None:
    """Null out memos that only ever rendered as a stray dot.

    Rows imported before `canonical.clean_memo` existed kept the bank's placeholder
    memo verbatim, which the transaction row then showed as `. · Account`. Re-importing
    would not fix them — they dedup against themselves — so they are cleared in place.
    """
    op.execute(
        sa.text("UPDATE transactions SET memo = NULL WHERE TRIM(memo) IN :placeholders").bindparams(
            sa.bindparam("placeholders", value=_PLACEHOLDERS, expanding=True)
        )
    )


def downgrade() -> None:
    """No-op: the discarded placeholders carried no information to restore."""
