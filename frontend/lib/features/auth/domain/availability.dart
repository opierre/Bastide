/// Where the check that a registration value is still free stands.
enum Availability {
  /// Nothing to tell: the field is empty or malformed, or the check failed.
  /// Registration itself still refuses a taken value.
  unknown,

  /// Waiting for the user to pause, or for the sidecar's answer.
  checking,

  /// No account uses it.
  available,

  /// An account already uses it.
  taken,
}
