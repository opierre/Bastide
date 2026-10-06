/// How strong a typed password is, on the four-segment scale the register
/// screen draws.
///
/// The backend imposes no password policy (`UserRegister.password` is
/// `min_length=1`), so this is a frontend affordance — but the 03 spec gates
/// the submit button on it, which makes it a real rule rather than decoration.
/// Keeping it here rather than in the widget means the thresholds are testable
/// and the screen only renders the verdict.
enum PasswordStrength {
  /// Nothing typed yet — the meter is empty and no verdict shows.
  empty(filledSegments: 0),
  weak(filledSegments: 1),
  fair(filledSegments: 2),
  strong(filledSegments: 3),
  excellent(filledSegments: 4);

  const PasswordStrength({required this.filledSegments});

  final int filledSegments;

  /// Whether the password clears the bar for submission.
  bool get isAcceptable => filledSegments >= strong.filledSegments;
}

/// Scores [password] by counting independent qualities rather than by length
/// alone: a long single-case word and a short mixed one are both weak, and
/// only breadth pushes the meter up.
PasswordStrength scorePassword(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^\w\s]').hasMatch(password)) score++;

  return switch (score) {
    0 || 1 => PasswordStrength.weak,
    2 => PasswordStrength.fair,
    3 => PasswordStrength.strong,
    _ => PasswordStrength.excellent,
  };
}
