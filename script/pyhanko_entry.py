"""PyInstaller entry point for AZpdf's local PAdES runtime."""

import os

import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())

from pyhanko.__main__ import launch


if __name__ == "__main__":
    raise SystemExit(launch())
