#!/usr/bin/env bash
#
# build-token2-docs.sh
# --------------------
# Produces a ready-to-upload Token2 documentation site from a clean keyroost
# checkout. Nothing is committed back to keyroost.
#
# It:
#   1. clones keyroost (upstream or your fork) at a chosen ref,
#   2. copies the repo's docs/ folder into a fresh OUTPUT directory,
#   3. overlays the Token2 changes there: installs the Token2 OTP applet page,
#      adds it to every page's nav, adds the "About this edition" fork notice to
#      index.html, and (optionally) repoints absolute links to your host,
#   4. leaves OUTPUT ready to upload to your web host as-is.
#
# Usage:
#   ./build-token2-docs.sh [--repo URL] [--ref REF] [--out DIR] [--base-url URL]
#
# Defaults:
#   --repo      https://github.com/framefilter/keyroost.git
#   --ref       main
#   --out       ./token2-docs-site
#   --base-url  (none — keep relative links; pass your site URL to rewrite
#               absolute framefilter.github.io links)
#
set -euo pipefail

REPO="https://github.com/framefilter/keyroost.git"
REF="main"
OUT="./token2-docs-site"
BASE_URL="https://www.token2.swiss/kr-docs"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --ref)  REF="$2"; shift 2;;
    --out)  OUT="$2"; shift 2;;
    --base-url) BASE_URL="$2"; shift 2;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown argument: $1" >&2; exit 1;;
  esac
done

say() { printf '\033[1;35m> %s\033[0m\n' "$*"; }

if [[ -e "$OUT" ]]; then
  echo "output dir '$OUT' already exists - remove it or pass --out" >&2
  exit 1
fi

# 1. clone into a temp dir (we only need docs/).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
say "Cloning $REPO @ $REF"
git clone --depth 1 --branch "$REF" "$REPO" "$TMP/repo" 2>/dev/null \
  || git clone "$REPO" "$TMP/repo"
git -C "$TMP/repo" checkout "$REF" 2>/dev/null || true

if [[ ! -d "$TMP/repo/docs" ]]; then
  echo "error: the repo has no docs/ folder" >&2
  exit 1
fi

# 2. copy docs/ into the fresh output dir.
say "Copying docs/ into $OUT"
mkdir -p "$OUT"
cp -r "$TMP/repo/docs/." "$OUT/"

# Drop internal developer notes that aren't part of the public site.
for f in BRINGUP.md DEVICE-RESEARCH.md PROTOCOL.md; do
  [[ -f "$OUT/$f" ]] && rm -f "$OUT/$f" && say "Removed internal note: $f"
done

# 3. overlay the Token2 changes in place.
say "Applying Token2 documentation overlay"
ARGS=(--docs "$OUT" --page "$SELF_DIR/token2-otp.html")
[[ -n "$BASE_URL" ]] && ARGS+=(--base-url "$BASE_URL")
python3 "$SELF_DIR/apply_docs_branding.py" "${ARGS[@]}"

say "Done."
echo
echo "  Ready-to-upload site:  $OUT"
echo "  Upload the entire contents of that folder to your web host."
[[ -n "$BASE_URL" ]] && echo "  Absolute links repointed to: $BASE_URL"
