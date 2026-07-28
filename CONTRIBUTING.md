# Contributing to AZpdf

**English** | [Tiếng Việt](CONTRIBUTING.vi.md)

Thanks for helping make AZpdf better.

## Reporting bugs

Include your macOS version, the AZpdf version, and minimal steps to reproduce.

## Proposing features

Open an issue before starting a large feature so we can agree on the design
direction first.

## Dev quickstart

Requires macOS 14+ and Xcode 26.

```
brew install mupdf verapdf
./script/build_and_run.sh
```

Before sending a pull request, all of these must be green:

```
swift test
./script/audit_local_first.sh
./script/audit_portable_core.sh
./script/audit_i18n_strings.sh
```

Any new user-facing string needs an entry in **both**
`Resources/en.lproj/Localizable.strings` and `Resources/vi.lproj/Localizable.strings` —
`audit_i18n_strings.sh` blocks CI otherwise.

## Guidelines

- Keep the native macOS look and feel, with full keyboard and VoiceOver support.
- Do not commit Homebrew binaries, Python virtualenvs, certificates/private keys, or
  notarization secrets to the repository. Release runtimes must pass `script/audit_runtime.sh`.
- All contributions are released under AGPL-3.0-only.
