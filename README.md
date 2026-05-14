# KeepAwake

Personal macOS menubar app to prevent system idle sleep, optionally gated on a configured Wi-Fi network.

**Important:** Does NOT keep Mac awake with lid closed on battery. Apple Silicon firmware enforces sleep below the kernel. No software bypass exists. For commute-coding, use a remote dev box and SSH from your phone.

## Requirements

- macOS 14+ (Apple Silicon)
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
./build.sh
```

Produces `KeepAwake.app`. Move to `~/Applications/`.

## Tests

```bash
./run-tests.sh
```

## Manual smoke test

See `SMOKE_TEST.md`.

## Design + plan

- Spec: `docs/superpowers/specs/2026-05-13-keepawake-menubar-design.md`
- Plan: `docs/superpowers/plans/2026-05-13-keepawake-menubar.md`
