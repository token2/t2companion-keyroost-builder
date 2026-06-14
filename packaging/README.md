# Packaging — distributables for Token2 Companion Keyroost

This folder shows how the rebranded keyroost GUI is turned into end-user
distributables:

| Platform | Artifact | Tool |
|----------|----------|------|
| Linux | `.AppImage` (single self-contained executable) | `linuxdeploy` |
| Windows | `Setup .exe` (installer with shortcuts + uninstaller) | Inno Setup 6 |
| macOS | `.dmg` (drag-to-Applications, universal2 `.app`) | `hdiutil` + `iconutil` |

Upstream keyroost's own release workflow ships **bare binaries in archives**
(`.tar.gz` / `.zip`). This packaging layer wraps those binaries into the
install-friendly formats users expect.

```
packaging/
├── package.yml                 GitHub Actions workflow building both (illustrative)
├── linux/
│   └── build-appimage.sh       assemble AppDir + build the AppImage
└── windows/
    ├── token2-companion.iss     Inno Setup script (placeholders filled at build)
    ├── build-installer.ps1      fills the .iss and runs iscc.exe
    └── png_to_ico.py            PNG -> .ico helper (Inno needs an .ico)
```

## Prerequisites

Both start from a **rebranded checkout** — the folder produced by
`rebrand-token2-companion.{ps1,sh}`. Build that first (the OTP feature is in
upstream now, so no patch is needed):

```bash
./rebrand-token2-companion.sh --repo https://github.com/framefilter/keyroost.git --out build
```
```powershell
.\rebrand-token2-companion.ps1 -Repo https://github.com/framefilter/keyroost.git -Out build
```

The GUI itself needs a recent Rust toolchain plus the platform build deps
(PC/SC headers and the windowing/GL libraries on Linux; nothing extra on
Windows/macOS — PC/SC and HID are part of the OS).

## Linux — AppImage

```bash
./packaging/linux/build-appimage.sh --project ./build --name "Token2 Companion Rust version - Keyroost"
```

What it does:
1. builds the release binary if one isn't there,
2. assembles an **AppDir** (binary in `usr/bin`, an `AppRun` entrypoint, a
   `.desktop` file, and the Token2 icon at the paths AppImage expects),
3. downloads `linuxdeploy` and packs the AppDir — bundling the binary's shared
   libraries — into a single `dist/*.AppImage`.

The user then just does `chmod +x *.AppImage && ./*.AppImage`. PC/SC is a system
service (`pcscd`), so it is depended on rather than bundled — the user needs
`pcscd` running, as with any smart-card software.

`--appdir-only` stops after step 2 (useful for inspecting the layout without
fetching linuxdeploy).

## Windows — Setup .exe

Install **Inno Setup 6** first (https://jrsoftware.org/isdl.php), then:

```powershell
.\packaging\windows\build-installer.ps1 -Project .\build -Name "Token2 Companion Rust version - Keyroost" -Version 0.4.0
```

What it does:
1. builds `keyroost.exe` + `keyroostctl.exe` if needed,
2. converts the branding PNG to an `.ico` (via `png_to_ico.py`, needs Pillow),
3. fills the placeholders in `token2-companion.iss` and compiles it with
   `iscc.exe` into `dist\token2-companion-keyroost-setup.exe`.

The installer offers per-machine or per-user install, creates Start Menu (and
optional desktop) shortcuts, and registers an uninstaller.

## macOS — DMG

Run on macOS (Xcode command-line tools provide `iconutil`/`hdiutil`/`lipo`):

```bash
./packaging/macos/build-dmg.sh --project ./build --name "Token2 Companion Rust version - Keyroost" --universal
```

What it does:
1. builds the release binary (`--universal` builds both arches and `lipo`s them
   into one universal2 binary that runs on Apple Silicon and Intel),
2. wraps it in a proper `.app` bundle (`Contents/MacOS`, `Info.plist`, and an
   `.icns` icon generated from the branding PNG),
3. packages the `.app` plus an `/Applications` symlink into a drag-to-install
   `dist/token2-companion-keyroost.dmg`.

`--app-only` stops after building the `.app` (useful for inspecting the bundle).

## CI

`package.yml` runs all builds on manual dispatch or a version tag and uploads
the artifacts. Drop it in `.github/workflows/` of your packaging repo. It
rebrands a fresh upstream checkout each run, so the repo carries only the
packaging recipes — not a vendored copy of keyroost.

## Honest notes / caveats

- **Tested vs. not:** the AppDir assembly logic was verified; the *full*
  AppImage build (linuxdeploy) and the Inno compile were **not** run in the
  environment that produced these scripts — they need a real Linux box with the
  GUI's build deps and a Windows box with Inno Setup. Expect to run each once and
  fix any environment-specific detail (a missing `-dev` package, an iscc path).
- **No code signing.** These produce *unsigned* artifacts. Windows SmartScreen
  will warn on an unsigned installer; distros are fine with unsigned AppImages
  but users must trust the source. On macOS an unsigned `.app` is blocked by
  Gatekeeper — users must right-click → Open (or you sign + notarize). For
  production, add Authenticode signing on Windows and Developer-ID signing +
  notarization (`codesign` + `notarytool`) on macOS.
- **Versioning.** `-Version` on Windows and the AppImage filename are not wired
  to the crate version automatically; pass the version you're releasing, or wire
  it from `git describe` in CI.
- **The AppId GUID** in `build-installer.ps1` is a fixed example. Keep it stable
  across releases (it's how Windows recognizes upgrades vs. fresh installs); only
  change it if you fork into a separate product.
