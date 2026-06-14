#!/usr/bin/env bash
#
# build-appimage.sh — package the rebranded keyroost GUI as a Linux AppImage.
#
# An AppImage is a single self-contained executable file: the user downloads it,
# marks it executable, and runs it — no install step, works across most distros.
#
# This script expects a release build to already exist, OR it will build one.
# Run it from the root of a rebranded checkout (the folder the rebrand script
# produced), or pass --project to point at one.
#
# Usage:
#   ./build-appimage.sh [--project DIR] [--name "App Name"] [--appdir-only]
#
# Requirements (host): cargo + the GUI's build deps, plus `wget`/`curl` to fetch
# linuxdeploy on first run. PC/SC at runtime needs libpcsclite on the user's
# machine (pcscd running) — AppImage bundles the app's own libs but PC/SC is a
# system service, so we depend on it rather than bundle it.
#
set -euo pipefail

PROJECT="."
APP_NAME="Token2 Companion Rust version - Keyroost"
APPID="token2-companion-keyroost"     # filesystem-safe id (no spaces)
BIN="keyroost"                         # the GUI binary name in the workspace
APPDIR_ONLY=0
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --name) APP_NAME="$2"; shift 2;;
    --appid) APPID="$2"; shift 2;;
    --appdir-only) APPDIR_ONLY=1; shift;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown argument: $1" >&2; exit 1;;
  esac
done

PROJECT="$(cd "$PROJECT" && pwd)"
say() { printf '\033[1;35m> %s\033[0m\n' "$*"; }

# ---- 1. ensure a release binary exists -------------------------------------
BINPATH="$PROJECT/target/release/$BIN"
if [[ ! -x "$BINPATH" ]]; then
  say "Building release binary ($BIN)"
  ( cd "$PROJECT" && cargo build --release --locked -p "$BIN" )
fi
[[ -x "$BINPATH" ]] || { echo "build did not produce $BINPATH" >&2; exit 1; }

# ---- 2. assemble the AppDir ------------------------------------------------
say "Assembling AppDir"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
APPDIR="$WORK/AppDir"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp "$BINPATH" "$APPDIR/usr/bin/$APPID"

# Icon: prefer the rebrand's app icon; fall back to the in-repo branding icon.
ICON_SRC=""
for cand in \
    "$SELF_DIR/../branding/icon-256.png" \
    "$PROJECT/crates/keyroost/assets/branding/app-icon.png"; do
  [[ -f "$cand" ]] && ICON_SRC="$cand" && break
done
if [[ -n "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APPID.png"
  cp "$ICON_SRC" "$APPDIR/$APPID.png"          # top-level icon AppImage expects
else
  say "WARNING: no icon found; AppImage will use a generic icon"
fi

# .desktop file (top-level copy is what AppImage reads).
cat > "$APPDIR/$APPID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec=$APPID
Icon=$APPID
Categories=Utility;Security;
Terminal=false
Comment=Manage Token2 and other FIDO2 / OATH / PIV / OpenPGP security keys
EOF
cp "$APPDIR/$APPID.desktop" "$APPDIR/usr/share/applications/$APPID.desktop"

# AppRun entrypoint.
cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\${0}")")"
exec "\$HERE/usr/bin/$APPID" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

if [[ "$APPDIR_ONLY" == "1" ]]; then
  OUT="$PROJECT/dist/AppDir"
  mkdir -p "$PROJECT/dist"; rm -rf "$OUT"; cp -r "$APPDIR" "$OUT"
  say "AppDir ready: $OUT (skipped AppImage build)"
  exit 0
fi

# ---- 3. fetch linuxdeploy and build the AppImage ---------------------------
say "Fetching linuxdeploy"
LD="$WORK/linuxdeploy-x86_64.AppImage"
URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
if command -v wget >/dev/null; then wget -qO "$LD" "$URL"; else curl -fsSL -o "$LD" "$URL"; fi
chmod +x "$LD"

say "Building AppImage"
mkdir -p "$PROJECT/dist"
# linuxdeploy bundles the binary's shared-library dependencies into the AppDir,
# then packs it into a single .AppImage. We pass the desktop+icon explicitly.
( cd "$WORK" && \
  "$LD" --appdir "$APPDIR" \
        --desktop-file "$APPDIR/$APPID.desktop" \
        --icon-file "$APPDIR/$APPID.png" \
        --output appimage )

mv "$WORK"/*.AppImage "$PROJECT/dist/" 2>/dev/null || \
  mv "$WORK"/../*.AppImage "$PROJECT/dist/" 2>/dev/null || true
say "Done. AppImage(s) in: $PROJECT/dist/"
ls -1 "$PROJECT/dist/"*.AppImage 2>/dev/null || \
  echo "  (if no file is listed, check linuxdeploy output above)"
