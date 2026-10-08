/// The display name doubles as the username, so it follows the backend's
/// format (`DisplayName` in `features/auth/schemas.py`): 3 to 32 letters,
/// digits, `.`, `_` or `-`. No `@`, which is how login tells it from an email.
/// Case doesn't matter — the backend stores it lowercased.
bool isValidDisplayName(String value) =>
    _displayNamePattern.hasMatch(value.trim());

final _displayNamePattern = RegExp(r'^[a-zA-Z0-9._-]{3,32}$');
