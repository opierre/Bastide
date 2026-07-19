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
