# Contributing to KeepAwake

KeepAwake is a small personal tool, but PRs are welcome — bug fixes, small features, and tests especially.

## Prerequisites

- macOS 14+ on Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+ (bundled with the CLT)

## Build locally

```sh
./build.sh
```

This compiles the AppKit binary, assembles `KeepAwake.app`, and ad-hoc signs it (`codesign -s -`).

To run the built app:

```sh
open KeepAwake.app
```

## Run tests

```sh
swift test
```

or the convenience wrapper:

```sh
./run-tests.sh
```

The XCTest suite must stay green before a PR is merged. CI runs `swift test` and `./build.sh` on every push and PR (see `.github/workflows/ci.yml`).

## Code style

- Follow the patterns already in the codebase — keep types small, prefer composition over inheritance, and keep AppKit code on the main actor.
- Use TDD where practical: add or update a test in `Tests/` before changing behavior.
- No external dependencies unless absolutely necessary. This project intentionally has zero runtime deps.
- Format with default Swift conventions (4-space indent, trailing newline).

## PR process

1. Fork the repository.
2. Create a topic branch off `main` (e.g., `fix/menu-icon-state`).
3. Make your change, add tests, run `swift test` + `./build.sh` locally.
4. Open a PR against `main`. Describe the *why* in the PR body.
5. CI must be green. A maintainer will review.

## Releases

Releases are cut by pushing a `vX.Y.Z` tag. The release workflow builds, tests, zips `KeepAwake.app`, computes a SHA256 checksum, and publishes a GitHub Release with auto-generated notes. Contributors do not need to do anything beyond merging to `main`.

## Reporting issues

Use the bug or feature templates in `.github/ISSUE_TEMPLATE/`. For bugs, please include `pmset -g assertions | grep -i KeepAwake` output when the bug relates to wake/sleep behavior.
