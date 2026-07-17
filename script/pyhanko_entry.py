"""PyInstaller entry point for AZpdf's local PAdES runtime."""

from pyhanko.__main__ import launch


if __name__ == "__main__":
    raise SystemExit(launch())
