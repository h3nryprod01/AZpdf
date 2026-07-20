#!/usr/bin/env python3
"""Generate checksum-pinned Flatpak sources from a Dart pubspec.lock file."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


PACKAGE_START = re.compile(r"^  ([A-Za-z0-9_]+):\s*$")
FIELD = re.compile(r"^    (source|version):\s*(.+?)\s*$")
SHA256 = re.compile(r"^      sha256:\s*(.+?)\s*$")


def yaml_scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def hosted_packages(lockfile: Path) -> list[tuple[str, str, str]]:
    packages: list[tuple[str, str, str]] = []
    current_name: str | None = None
    fields: dict[str, str] = {}

    def finish() -> None:
        nonlocal current_name, fields
        if current_name is None:
            return
        if fields.get("source") == "hosted":
            missing = {"version", "sha256"} - fields.keys()
            if missing:
                raise ValueError(
                    f"{current_name} thiếu field bắt buộc: {', '.join(sorted(missing))}"
                )
            packages.append((current_name, fields["version"], fields["sha256"]))
        current_name = None
        fields = {}

    for line in lockfile.read_text(encoding="utf-8").splitlines():
        package_match = PACKAGE_START.match(line)
        if package_match:
            finish()
            current_name = package_match.group(1)
            continue
        if current_name is None:
            continue
        field_match = FIELD.match(line)
        if field_match:
            fields[field_match.group(1)] = yaml_scalar(field_match.group(2))
            continue
        sha_match = SHA256.match(line)
        if sha_match:
            fields["sha256"] = yaml_scalar(sha_match.group(1))
    finish()
    return sorted(packages)


def sources(lockfiles: list[Path]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    packages: dict[tuple[str, str], str] = {}
    for lockfile in lockfiles:
        for name, version, sha256 in hosted_packages(lockfile):
            key = (name, version)
            previous = packages.get(key)
            if previous is not None and previous != sha256:
                raise ValueError(
                    f"{name} {version} co checksum mau thuan giua cac lockfile"
                )
            packages[key] = sha256

    for (name, version), sha256 in sorted(packages.items()):
        result.append(
            {
                "type": "archive",
                "url": f"https://pub.dev/api/archives/{name}-{version}.tar.gz",
                "sha256": sha256,
                "strip-components": 0,
                "dest": f"pub-cache/hosted/pub.dev/{name}-{version}",
            }
        )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("lockfile", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--additional-lockfile",
        action="append",
        default=[],
        type=Path,
        help="Lockfile bo sung, vi du dependency noi bo cua Flutter SDK.",
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    rendered = json.dumps(
        sources([args.lockfile, *args.additional_lockfile]),
        indent=2,
        ensure_ascii=True,
    ) + "\n"
    if args.check:
        if not args.output.is_file() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit(f"{args.output} không khớp {args.lockfile}; hãy regenerate.")
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
