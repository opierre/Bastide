/// The display name doubles as the username, so it follows the backend's
/// format (`DisplayName` in `features/auth/schemas.py`): 3 to 32 letters,
/// digits, spaces, `.`, `_` or `-`, counted once trimmed and with each run of
/// inner spaces collapsed to one. No `@`, which is how login tells it from an
/// email. The backend keeps the case typed; uniqueness and sign-in ignore it.
bool isValidDisplayName(String value) =>
    _displayNamePattern.hasMatch(normalizeDisplayName(value));

/// [value] trimmed, with each run of inner spaces collapsed to one, as the
/// backend stores it: « Camille  Dubois » is « Camille Dubois ».
String normalizeDisplayName(String value) =>
    value.trim().replaceAll(_innerSpaces, ' ');

final _displayNamePattern = RegExp(r'^[a-zA-Z0-9._ -]{3,32}$');

final _innerSpaces = RegExp(r' {2,}');
