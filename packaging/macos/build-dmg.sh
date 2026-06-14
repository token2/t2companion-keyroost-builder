#!/usr/bin/env bash
#
# build-dmg.sh — package the rebranded keyroost GUI as a macOS .app + .dmg.
#
# macOS apps are *bundles* (Foo.app/Contents/{MacOS,Resources,Info.plist}), not
# bare binaries. This script builds (or reuses) the release binary, wraps it in
# a .app bundle with the Token2 icon, and packages that into a drag-to-Applications
# .dmg.
#
# Run on macOS, from a rebranded checkout (or pass --project).
#
# Usage:
#   ./build-dmg.sh [--project DIR] [--name "App Name"] [--universal] [--app-only]
#
# Requirements (host): Xcode command-line tools (for `iconutil`, `lipo`,
# `hdiutil` — all part of macOS), a Rust toolchain, and `sips` (built in).
#   --universal  build both arches and lipo into one universal2 binary.
#
set -euo pipefail

PROJECT="."
APP_NAME="Token2 Companion Rust version - Keyroost"
BIN="keyroost"
BUNDLE_ID="swiss.token2.companion.keyroost"
UNIVERSAL=0
APP_ONLY=0
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --name) APP_NAME="$2"; shift 2;;
    --bundle-id) BUNDLE_ID="$2"; shift 2;;
    --universal) UNIVERSAL=1; shift;;
    --app-only) APP_ONLY=1; shift;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown argument: $1" >&2; exit 1;;
  esac
done

PROJECT="$(cd "$PROJECT" && pwd)"
say() { printf '\033[1;35m> %s\033[0m\n' "$*"; }

# ---- 1. build the release binary -------------------------------------------
if [[ "$UNIVERSAL" == "1" ]]; then
  say "Building universal2 binary"
  ( cd "$PROJECT" && \
    cargo build --release --locked --target aarch64-apple-darwin -p "$BIN" && \
    cargo build --release --locked --target x86_64-apple-darwin  -p "$BIN" )
  BINPATH="$PROJECT/target/$BIN-universal"
  lipo -create -output "$BINPATH" \
    "$PROJECT/target/aarch64-apple-darwin/release/$BIN" \
    "$PROJECT/target/x86_64-apple-darwin/release/$BIN"
else
  BINPATH="$PROJECT/target/release/$BIN"
  if [[ ! -x "$BINPATH" ]]; then
    say "Building release binary"
    ( cd "$PROJECT" && cargo build --release --locked -p "$BIN" )
  fi
fi
[[ -f "$BINPATH" ]] || { echo "binary not found: $BINPATH" >&2; exit 1; }

# ---- 2. assemble the .app bundle -------------------------------------------
say "Assembling ${APP_NAME}.app"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
APP="$WORK/${APP_NAME}.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINPATH" "$APP/Contents/MacOS/$BIN"
chmod +x "$APP/Contents/MacOS/$BIN"

# Icon: build an .icns from the branding PNG (prefer the 256+ source).
ICON_SRC=""
for cand in \
    "$SELF_DIR/../branding/icon-256.png" \
    "$PROJECT/crates/keyroost/assets/branding/app-icon.png"; do
  [[ -f "$cand" ]] && ICON_SRC="$cand" && break
done
if [[ -n "$ICON_SRC" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
  ICONSET="$WORK/icon.iconset"; mkdir -p "$ICONSET"
  for s in 16 32 64 128 256 512; do
    sips -z $s $s "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s*2))
    sips -z $d $d "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/app.icns"
  ICON_PLIST="<key>CFBundleIconFile</key><string>app</string>"
else
  say "WARNING: no icon (or sips/iconutil unavailable); bundle will use the default icon"
  ICON_PLIST=""
fi

# Info.plist. LSUIElement=false so it shows in the Dock; the GUI is a normal app.
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>${BIN}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  ${ICON_PLIST}
</dict>
</plist>
EOF

if [[ "$APP_ONLY" == "1" ]]; then
  mkdir -p "$PROJECT/dist"; rm -rf "$PROJECT/dist/${APP_NAME}.app"
  cp -r "$APP" "$PROJECT/dist/"
  say ".app ready: $PROJECT/dist/${APP_NAME}.app (skipped DMG)"
  exit 0
fi

# ---- 3. package the .dmg ---------------------------------------------------
say "Packaging .dmg"
STAGE="$WORK/stage"; mkdir -p "$STAGE"
cp -r "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install target

mkdir -p "$PROJECT/dist"
DMG="$PROJECT/dist/token2-companion-keyroost.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$STAGE" -ov -format UDZO "$DMG"

say "Done. DMG: $DMG"
echo "  (Unsigned — see README for signing/notarization notes.)"
