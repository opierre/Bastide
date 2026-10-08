"""Argon2id password hashing and opaque bearer-token generation."""

import secrets

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

_password_hasher = PasswordHasher()

_TOKEN_BYTES = 32


def hash_password(password: str) -> str:
    """Hash a plaintext password with Argon2id. Never store the plaintext."""
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """Verify a plaintext password against its Argon2id hash."""
    try:
        return _password_hasher.verify(password_hash, password)
    except VerifyMismatchError:
        return False


def generate_token() -> str:
    """Generate a cryptographically random opaque bearer token."""
    return secrets.token_urlsafe(_TOKEN_BYTES)


# Crockford base32: no I, L, O or U, so a code copied by hand can't be misread.
_RECOVERY_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_RECOVERY_GROUPS = 5
_RECOVERY_GROUP_LENGTH = 4


def generate_recovery_code() -> str:
    """Generate a recovery code like ``7K2M-QX9D-...``: 20 symbols, 100 bits of entropy.

    That much entropy makes guessing hopeless without rate limiting, unlike a short PIN.
    """
    groups = (
        "".join(secrets.choice(_RECOVERY_ALPHABET) for _ in range(_RECOVERY_GROUP_LENGTH))
        for _ in range(_RECOVERY_GROUPS)
    )
    return "-".join(groups)


def normalize_recovery_code(code: str) -> str:
    """Canonical form for hashing: uppercase, no separators, Crockford look-alikes folded."""
    compact = "".join(code.split()).replace("-", "").upper()
    return compact.translate(str.maketrans({"I": "1", "L": "1", "O": "0"}))


def hash_recovery_code(code: str) -> str:
    """Hash a recovery code with Argon2id. Only the hash is stored; the code is shown once."""
    return _password_hasher.hash(normalize_recovery_code(code))


def verify_recovery_code(code: str, code_hash: str) -> bool:
    """Verify a recovery code as typed (any case, dashes or spaces) against its hash."""
    return verify_password(normalize_recovery_code(code), code_hash)
