/// Whether [value] reads as an email address: one `@` between a local part
/// and a dotted domain, no whitespace. The backend checks a changed email the
/// same way (`EMAIL_PATTERN` in `features/auth/schemas.py`). Callers trim
/// first.
bool isValidEmail(String value) => _emailPattern.hasMatch(value);

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
