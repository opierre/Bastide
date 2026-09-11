"""Bind a pack's `category_key`s to the importing user's category rows.

System categories store their i18n key in `categories.name` (`PROJECT.md` §4), which is exactly
what makes a pack portable: `category.food.groceries` resolves to the same row for a French user
and an English one, because the key is the identity and the display name is the frontend's job.
"""

from dataclasses import dataclass

from app.features.categories.repository import CategoryRepository
from app.features.rules.packs.schema import RulePack, RulePackEntry


@dataclass(frozen=True)
class ResolvedEntry:
    """A pack entry paired with the category id it will write."""

    entry: RulePackEntry
    category_id: str


@dataclass(frozen=True)
class Resolution:
    """The outcome of resolving a whole pack: what can be imported, and what cannot."""

    resolved: list[ResolvedEntry]
    unresolved: list[str]


def resolve_pack(pack: RulePack, categories: CategoryRepository, user_id: str) -> Resolution:
    """Map each entry's `category_key` to a system category, reporting the keys that miss.

    A key with no match is reported and its rule skipped; **a category is never created**. A
    stranger's file must not be able to reshape someone's category tree, and a silently invented
    category is worse than a reported gap the user can act on.

    Because only system rows are consulted, rules targeting a user-defined category are not
    expressible in version 1 of the format. That is a deliberate limit — see the omissions the
    export reports.

    Returns:
        The resolvable entries in pack order, and the distinct unresolved keys in the order they
        were first seen (the frontend lists them back to the user, so a stable order matters).
    """
    keys = {entry.category_key for entry in pack.rules}
    by_key = {
        category.name: category.id
        for category in categories.list_system_by_names_for_user(sorted(keys), user_id)
    }

    resolved: list[ResolvedEntry] = []
    unresolved: list[str] = []
    for entry in pack.rules:
        category_id = by_key.get(entry.category_key)
        if category_id is None:
            if entry.category_key not in unresolved:
                unresolved.append(entry.category_key)
            continue
        resolved.append(ResolvedEntry(entry=entry, category_id=category_id))
    return Resolution(resolved=resolved, unresolved=unresolved)
