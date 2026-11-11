"""Fixtures for the run progress tests.

The end-to-end tests drive a real categorisation run, so they borrow that feature's stub
runtime, hand-driven launcher and session factory rather than duplicating them.
"""

from tests.features.categorization.conftest import (  # noqa: F401 — re-exported fixtures.
    api_session_factory,
    launcher,
    runtime,
)
