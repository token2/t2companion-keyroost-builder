#!/usr/bin/env python3
"""
apply_docs_branding.py — overlay Token2 documentation onto a keyroost docs/ tree.

Like the app rebrand, this keeps the changes OUT of upstream: run it against a
fresh `docs/` checkout to produce the Token2-focused documentation site.

It:
  1. drops in token2-otp.html (the new applet page),
  2. inserts a "Token2 OTP" nav link into every page, after the OATH link,
  3. adds an "About this edition" fork notice to index.html,
  4. (optionally) repoints absolute framefilter.github.io links to your host.

Usage:
  python3 apply_docs_branding.py --docs ./docs [--page ./token2-otp.html]
                                 [--base-url https://www.token2.swiss/keyroost]
"""

import argparse
import sys
from pathlib import Path

NAV_OLD = '<a href="oath.html">OATH</a>'
NAV_NEW = ('<a href="oath.html">OATH</a>\n'
           '      <a href="token2-otp.html">Token2 OTP</a>')

FORK_NOTICE = '''  <div class="kr-callout note" style="margin-top:18px">
    <div class="kr-callout-title note">About this edition</div>
    <p>This is a <strong>Token2-focused edition</strong> of
      <a href="https://github.com/framefilter/keyroost">keyroost</a> — an
      independent, open-source Rust toolchain for hardware security keys. It is a
      fork, rebranded and re-documented to centre on
      <strong>Token2 PIN+ / T2F2 FIDO keys</strong>, and it adds first-class
      support for the <a href="token2-otp.html">Token2 on-device OTP applet</a>
      (TOTP/HOTP over CCID/NFC and USB-HID). The underlying engine is unchanged:
      everything is implemented from public standards, with no vendor SDKs, and it
      still works with FIDO2, OATH, OpenPGP, and PIV on keys from any vendor.</p>
  </div>

'''
FORK_ANCHOR = '<main class="kr-wrap">\n\n  <section class="kr-section" id="what">'
FORK_REPLACE = '<main class="kr-wrap">\n\n' + FORK_NOTICE + '  <section class="kr-section" id="what">'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--docs", required=True, help="path to the keyroost docs/ folder")
    ap.add_argument("--page", default="", help="path to token2-otp.html to install")
    ap.add_argument("--base-url", default="",
                    help="if set, rewrite absolute framefilter.github.io/keyroost links to this base")
    args = ap.parse_args()

    docs = Path(args.docs)
    if not (docs / "index.html").exists():
        print(f"error: {docs} does not look like a keyroost docs/ folder", file=sys.stderr)
        sys.exit(1)

    # 1. Install the new applet page.
    if args.page:
        src = Path(args.page)
        if not src.exists():
            print(f"error: --page {src} not found", file=sys.stderr)
            sys.exit(1)
        (docs / "token2-otp.html").write_text(src.read_text(encoding="utf-8"),
                                              encoding="utf-8")
        print("  · installed token2-otp.html")

    # 2. Insert the nav link into every .html page that has the OATH nav entry.
    for html in sorted(docs.glob("*.html")):
        text = html.read_text(encoding="utf-8")
        changed = False
        # nav link (skip if already present)
        if 'token2-otp.html">Token2 OTP</a>' not in text and NAV_OLD in text:
            text = text.replace(NAV_OLD, NAV_NEW, 1)
            changed = True
        # 3. fork notice on the landing page only
        if html.name == "index.html" and "About this edition" not in text \
                and FORK_ANCHOR in text:
            text = text.replace(FORK_ANCHOR, FORK_REPLACE, 1)
            changed = True
        # 4. optional absolute-link rewrite
        if args.base_url:
            base = args.base_url.rstrip("/")
            text2 = text.replace("https://framefilter.github.io/keyroost", base)
            if text2 != text:
                text = text2
                changed = True
        if changed:
            html.write_text(text, encoding="utf-8")
            print(f"  · patched {html.name}")

    print("docs overlay complete.")


if __name__ == "__main__":
    main()
