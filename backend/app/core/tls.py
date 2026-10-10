"""The TLS context every outgoing `httpx` client uses, built by hand rather than by default.

Two things on real machines break the default one. Antivirus HTTPS scanning (Avast, AVG)
re-signs traffic with a root it installs in the OS store, which `certifi` alone does not
trust, so both stores are loaded. The same products set `SSLKEYLOGFILE` to a named pipe, and
the key log that `ssl.create_default_context` (which `httpx` calls for its default) opens from
it aborts a Windows process outright with `OPENSSL_Applink`, even for a plain `http://`
request, since `httpx` builds the context whether or not TLS is used. A bare `SSLContext`
never opens a key log.
"""

import ssl

import certifi


def tls_context() -> ssl.SSLContext:
    """A verifying client context trusting the OS store and `certifi`, with no key log."""
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.load_default_certs()
    context.load_verify_locations(certifi.where())
    return context
