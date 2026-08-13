"""Portable, shareable sets of categorization rules.

A pack carries only `(field, type, pattern, category_key)` tuples — no ids, no priorities, no
user data — so the same file imports cleanly on any install. Importing one produces ordinary
`categorization_rules` rows that the P1 engine matches with `source='rule'`, which is why every
existing surface (review queue, rules editor, `POST /rules/apply`) handles them unchanged.
"""
