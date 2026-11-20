import 'dart:math' as math;

/// The one rule a new password has to meet: twelve characters
/// (`docs/design/03-register.md`).
///
/// The backend imposes no password policy (`UserRegister.password` is
/// `min_length=1`), so this is a frontend rule. Registration and the password
/// reset both gate their submit on it, so a reset can never reach a password
/// the register form would have refused.
const minPasswordLength = 12;

/// Whether [password] is long enough to submit.
bool isLongEnoughPassword(String password) =>
    password.length >= minPasswordLength;

/// How many characters [password] still lacks, `0` once it is long enough.
int missingPasswordCharacters(String password) =>
    math.max(0, minPasswordLength - password.length);
