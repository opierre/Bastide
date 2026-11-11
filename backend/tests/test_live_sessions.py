"""Tests for the registry closing long-lived connections when their auth session is revoked."""

from unittest.mock import Mock

from app.core.live_sessions import LiveSessions


def test_revoking_a_session_ends_only_its_connections() -> None:
    registry = LiveSessions()
    kept, ended = Mock(), Mock()
    registry.register("session-a", "user-1", ended)
    registry.register("session-b", "user-1", kept)

    registry.revoke_session("session-a")

    ended.assert_called_once_with()
    kept.assert_not_called()
    assert registry.count("user-1") == 1


def test_revoking_a_user_ends_every_session_of_theirs() -> None:
    registry = LiveSessions()
    first, second, other = Mock(), Mock(), Mock()
    registry.register("session-a", "user-1", first)
    registry.register("session-b", "user-1", second)
    registry.register("session-c", "user-2", other)

    registry.revoke_user("user-1")

    first.assert_called_once_with()
    second.assert_called_once_with()
    other.assert_not_called()
    assert registry.count() == 1


def test_an_unregistered_connection_is_not_ended() -> None:
    registry = LiveSessions()
    on_revoke = Mock()
    with registry.register("session-a", "user-1", on_revoke):
        pass

    registry.revoke_session("session-a")

    on_revoke.assert_not_called()
    assert registry.count() == 0


def test_a_failing_callback_does_not_stop_the_others() -> None:
    registry = LiveSessions()
    after = Mock()
    registry.register("session-a", "user-1", Mock(side_effect=RuntimeError("socket gone")))
    registry.register("session-a", "user-1", after)

    registry.revoke_session("session-a")

    after.assert_called_once_with()
