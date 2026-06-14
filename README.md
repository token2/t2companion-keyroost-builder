# t2companion-keyroost-builder

Build scripts and packaging recipes for **Token2 Companion Rust version -
Keyroost** — a Token2-focused distribution of the open-source
[keyroost](https://github.com/framefilter/keyroost) security-key toolchain.

This repository carries **only the recipes**, not a copy of keyroost. Each build
rebrands a fresh upstream checkout, so there's nothing to keep in sync and no
vendored source. The Token2 on-device OTP feature is already merged upstream, so
no patch is needed for current builds (one is included for building against
older bases).

## What's here

```
.
├── rebrand-token2-companion.ps1 / .sh   rebrand the app (clone -> brand -> ready to build)
├── apply_branding.py                    source-transform helper used by the above
├── branding/                            logo, background, generated app icons
├── token2-otp-complete.patch            OTP feature patch (only for pre-merge bases)
├── packaging/                           turn the built app into distributables
│   ├── linux/build-appimage.sh              -> .AppImage
│   ├── windows/  (build-installer.ps1, .iss) -> Setup .exe (Inno Setup)
│   ├── macos/build-dmg.sh                    -> .dmg (universal2 .app)
│   └── README.md
├── docs-builder/                        build the documentation site
│   ├── build-token2-docs.ps1 / .sh
│   └── ...
└── .github/workflows/package.yml        CI: builds AppImage + Setup .exe + DMG
```

## Quick start

**1. Rebrand the app** (produces a buildable, branded checkout):

```powershell
# Windows
.\rebrand-token2-companion.ps1 -Out build
```
```bash
# Linux / macOS
./rebrand-token2-companion.sh --out build
```

Defaults: repo `framefilter/keyroost`, ref `main`, name "Token2 Companion Rust
version - Keyroost", patch skipped (feature is upstream). Override with
`-Repo/-Ref/-Name/-DocsUrl` (PowerShell) or `--repo/--ref/--name/--docs-url`
(bash).

**2. Build and run** (needs a Rust toolchain + platform deps):

```bash
cd build && cargo run -p keyroost
```

**3. Package a distributable** — see [`packaging/README.md`](packaging/README.md):

```bash
./packaging/linux/build-appimage.sh   --project ./build                  # Linux  -> .AppImage
./packaging/macos/build-dmg.sh        --project ./build --universal      # macOS  -> .dmg
# Windows (PowerShell, Inno Setup installed):
.\packaging\windows\build-installer.ps1 -Project .\build                 # -> Setup .exe
```

**Docs site** — see [`docs-builder/README.md`](docs-builder/README.md):

```powershell
.\docs-builder\build-token2-docs.ps1 -Out token2-docs-site
```

## CI

`.github/workflows/package.yml` builds all three artifacts (AppImage, Setup .exe,
DMG) on manual dispatch or a version tag, and uploads them. The artifacts are
**unsigned** — fine for demonstrating the build; We will use code signing for Releases

## Trademark

The Token2 name and logo are used here by the trademark owner.

## License

Pick a license for the build scripts (MIT recommended) and add a LICENSE file.
keyroost itself is dual MIT / Apache-2.0; this repo does not redistribute it — it
builds from upstream at run time.
