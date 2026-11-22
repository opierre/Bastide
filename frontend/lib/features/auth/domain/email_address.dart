/// Whether [value] looks like an e-mail address: something, `@`, a domain
/// with a dot. Deliberately loose; the backend only needs the `@` that tells
/// an e-mail from a username at sign-in.
bool isPlausibleEmail(String value) => _emailPattern.hasMatch(value);

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
