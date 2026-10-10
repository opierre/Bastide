"""The exact files the opt-in local runtime is built from, pinned by URL, size and SHA-256.

Nothing here is looked up at run time: the hashes live in the code, so a file that does not
match them is refused no matter what the server serving it claims. Moving to a newer build
or model means editing this file, in a reviewed commit, with hashes taken from the
publisher (GitHub's asset `digest`, Hugging Face's LFS `oid`) and checked against a download.

- `llama-server` comes from a llama.cpp release, the CPU build on Windows and Linux (it runs on
  any machine, with no GPU driver to be missing), the Metal-capable build on macOS.
- The model is Google's quantization-aware-trained Gemma 4 E4B at q4_0, the default
  categorization model.
"""

import platform
import sys
from dataclasses import dataclass
from typing import Literal

#: The llama.cpp release every platform's build is taken from.
LLAMA_CPP_BUILD = "b11541"

_RELEASE_URL = f"https://github.com/ggml-org/llama.cpp/releases/download/{LLAMA_CPP_BUILD}"

#: The name `llama-server` advertises the model under (`--alias`), and so the model tag the
#: app stores for it.
MODEL_ALIAS = "gemma-4-e4b-it"


@dataclass(frozen=True, slots=True)
class PinnedFile:
    """One file to download, and what it must hash to."""

    url: str
    filename: str
    size: int
    sha256: str


@dataclass(frozen=True, slots=True)
class RuntimeBuild:
    """A platform's `llama-server` archive and where the executable sits once extracted."""

    archive: PinnedFile
    kind: Literal["zip", "tar.gz"]
    #: Path of the executable relative to the extraction folder.
    server: str


def _build(name: str, size: int, sha256: str, server: str) -> RuntimeBuild:
    filename = f"llama-{LLAMA_CPP_BUILD}-bin-{name}"
    return RuntimeBuild(
        archive=PinnedFile(
            url=f"{_RELEASE_URL}/{filename}", filename=filename, size=size, sha256=sha256
        ),
        kind="zip" if name.endswith(".zip") else "tar.gz",
        server=server,
    )


RUNTIME_BUILDS: dict[str, RuntimeBuild] = {
    "windows-x64": _build(
        "win-cpu-x64.zip",
        19_518_702,
        "cdc0535d11038bb337dfba3c15682050eaa9c07aedd0f915b4c09e8a8e8c0a5c",
        "llama-server.exe",
    ),
    "macos-arm64": _build(
        "macos-arm64.tar.gz",
        12_078_846,
        "226929037cfcb956f50ae1d54bac13d3d9446d8d819c439580e1e2c00197da5e",
        f"llama-{LLAMA_CPP_BUILD}/llama-server",
    ),
    "linux-x64": _build(
        "ubuntu-x64.tar.gz",
        17_809_316,
        "36ca310be4405acb7ba59b32dbdce32bb9cd7b1ef95358997b7eaed2c6f0188b",
        f"llama-{LLAMA_CPP_BUILD}/llama-server",
    ),
}

MODEL = PinnedFile(
    url=(
        "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/"
        "gemma-4-E4B_q4_0-it.gguf"
    ),
    filename="gemma-4-E4B_q4_0-it.gguf",
    size=5_154_941_280,
    sha256="676c35070db6dbe52f93e9c864ee0fba4eddea94b9c875d9cb10daff453fbaee",
)


def platform_key(system: str = sys.platform, machine: str | None = None) -> str | None:
    """Name this machine's entry in `RUNTIME_BUILDS`, or `None` when there is no build for it."""
    arch = (machine if machine is not None else platform.machine()).lower()
    if system == "win32" and arch in ("amd64", "x86_64"):
        return "windows-x64"
    if system == "darwin" and arch == "arm64":
        return "macos-arm64"
    if system.startswith("linux") and arch in ("x86_64", "amd64"):
        return "linux-x64"
    return None


def runtime_build(key: str | None = None) -> RuntimeBuild | None:
    """This machine's build (or the one `key` names), `None` when unsupported."""
    resolved = platform_key() if key is None else key
    return RUNTIME_BUILDS.get(resolved) if resolved is not None else None
