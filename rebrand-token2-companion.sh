#!/usr/bin/env bash
#
# rebrand-token2-companion.sh
# ---------------------------
# Generates "Token2 Companion Keyroost" from a clean keyroost checkout.
#
# This script keeps ALL Token2 branding OUT of the keyroost repository. It:
#   1. clones keyroost (upstream or your fork) at a chosen ref,
#   2. optionally applies one or more feature patches (functionality only — no
#      branding), in the order given,
#   3. overlays branding as a post-checkout transform: app name, window title,
#      brand tile, accent palette (Token2 red), the window icon, and the
#      companion-app-style layout tweaks,
#   4. leaves you a ready-to-build, rebranded project directory.
#
# Nothing here is committed to keyroost; the rebrand is reproducible on demand.
#
# Usage:
#   ./rebrand-token2-companion.sh [--repo URL] [--ref REF] [--patch FILE]... [--out DIR]
#   --patch is repeatable, e.g. --patch bio-full.patch --patch otp-overview-card.patch
#
# Defaults:
#   --repo   https://github.com/framefilter/keyroost.git   (use your fork to include the PR)
#   --ref    main
#   --patch  (none; OTP feature is upstream)
#   --out    ./token2-companion-keyroost
#
set -euo pipefail

# ---- configuration ---------------------------------------------------------
REPO="https://github.com/framefilter/keyroost.git"
REF="main"
PATCHES=()   # OTP feature is upstream now; pass --patch <file> (repeatable) to layer features
OUT="./token2-companion-keyroost"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="Token2 Companion Rust version - Keyroost"
APP_TAGLINE="Manage Token2 and other FIDO2 / OATH / PIV / OpenPGP keys"
# Token2 brand red, sampled from the official logo gradient.
ACCENT_HEX="D60326"      # brand mid-red  (rgb 214,3,38)
ACCENT_BRIGHT="F2053D"   # top-left highlight
ACCENT_DEEP="AE0009"     # bottom-right shadow
# Documentation base URL — every "Learn" link and "?" popover points here.
# Set this to your token2.swiss docs site (content to be defined separately).
DOCS_URL="https://www.token2.swiss/kr-docs"

# ---- argument parsing ------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)  REPO="$2"; shift 2;;
    --ref)   REF="$2"; shift 2;;
    --patch) PATCHES+=("$2"); shift 2;;
    --out)   OUT="$2"; shift 2;;
    --name)  APP_NAME="$2"; shift 2;;
    --docs-url) DOCS_URL="$2"; shift 2;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown argument: $1" >&2; exit 1;;
  esac
done

say() { printf '\033[1;35m▸ %s\033[0m\n' "$*"; }

# ---- 1. clone --------------------------------------------------------------
if [[ -e "$OUT" ]]; then
  echo "output dir '$OUT' already exists — remove it or pass --out" >&2
  exit 1
fi
say "Cloning $REPO @ $REF"
git clone "$REPO" "$OUT"
git -C "$OUT" checkout "$REF"

# ---- 2. apply feature patches (functionality only) -------------------------
# Pass --patch <file> one or more times to layer optional features (applied in
# order), e.g. --patch bio-full.patch --patch otp-overview-card.patch
if [[ ${#PATCHES[@]} -eq 0 ]]; then
  say "No patches given — assuming features are already in $REPO"
else
  for PF in "${PATCHES[@]}"; do
    if [[ ! -f "$PF" ]]; then
      echo "  ! patch file not found: $PF" >&2
      exit 1
    fi
    # Resolve to absolute: git runs with -C "$OUT", so a relative path (given
    # relative to the caller's CWD) would otherwise not be found.
    PF_ABS="$(cd "$(dirname "$PF")" && pwd)/$(basename "$PF")"
    say "Applying patch: $(basename "$PF")"
    if git -C "$OUT" apply --check "$PF_ABS" 2>/dev/null; then
      git -C "$OUT" apply "$PF_ABS"
    else
      echo "  ! patch did not apply cleanly against $REF: $PF" >&2
      exit 1
    fi
  done
fi

# ---- 3. branding overlay ---------------------------------------------------
say "Applying Token2 Companion branding"

# 3a. Materialize the window icon from the embedded asset.
mkdir -p "$OUT/crates/keyroost/assets/branding"
base64 -d "$SELF_DIR/branding/icon-256.b64" > "$OUT/crates/keyroost/assets/branding/app-icon.png"

# 3b. Run the Rust-source transforms via the bundled Python helper, which does
#     the name/title/accent/icon/glyph edits and the companion-style layout.
python3 "$SELF_DIR/apply_branding.py" \
  --root "$OUT" \
  --app-name "$APP_NAME" \
  --tagline "$APP_TAGLINE" \
  --accent "$ACCENT_HEX" \
  --accent-bright "$ACCENT_BRIGHT" \
  --accent-deep "$ACCENT_DEEP" \
  --docs-url "$DOCS_URL"

say "Done."
echo
echo "  Rebranded project:  $OUT"
echo "  Build & run:        cd $OUT && cargo run -p keyroost"
echo
echo "  The keyroost repo itself was not modified with any branding —"
echo "  everything above was overlaid onto a fresh checkout."
