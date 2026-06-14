# Token2 documentation site builder

Produces a **ready-to-upload** Token2-focused documentation site from a clean
keyroost checkout. The script clones the repo, copies its `docs/` folder into a
fresh output directory, applies the Token2 changes there, and leaves you a folder
you can upload to your web host as-is. Nothing is committed back to keyroost.

## Files

- `build-token2-docs.ps1` — Windows: clone -> copy docs -> patch -> ready folder
- `build-token2-docs.sh` — Linux/macOS equivalent
- `apply_docs_branding.py` — the overlay helper (called by the scripts)
- `token2-otp.html` — the new applet page (byte-matched to the site template)
- `index.html`, `token2-otp.md` — reference copies (not required by the scripts)

## Usage

### Windows

```powershell
.\build-token2-docs.ps1 -Repo https://github.com/token2/keyroost.git -Ref main `
  -Out token2-docs-site -BaseUrl https://www.token2.swiss/kr-docs
```

### Linux / macOS

```bash
./build-token2-docs.sh --repo https://github.com/token2/keyroost.git --ref main \
  --out token2-docs-site --base-url https://www.token2.swiss/kr-docs
```

Then upload the **entire contents** of the output folder (`token2-docs-site/`)
to your web host.

### Parameters

| Windows | bash | meaning |
|---------|------|---------|
| `-Repo` | `--repo` | repo to clone (your fork, or upstream — default upstream) |
| `-Ref` | `--ref` | branch/tag (default `main`) |
| `-Out` | `--out` | output folder (default `token2-docs-site`) |
| `-BaseUrl` | `--base-url` | if set, rewrites absolute `framefilter.github.io/keyroost` links to this host |

`-BaseUrl` is optional. Omit it to keep the site's relative links (fine if you
host at the site root); pass your URL to repoint the few absolute links.

## What the build does

1. Clones keyroost and copies its `docs/` into the fresh output folder.
2. Removes internal dev notes (`BRINGUP.md`, `DEVICE-RESEARCH.md`,
   `PROTOCOL.md`) that aren't part of the public site.
3. Installs `token2-otp.html` (the Token2 on-device OTP applet page).
4. Adds a **"Token2 OTP"** nav link to every page (after OATH).
5. Adds the **"About this edition"** fork notice to `index.html`.
6. With `-BaseUrl`/`--base-url`, repoints absolute links to your host.

The new page is byte-matched to the site's own template (`kr-*` CSS classes,
theme toggle, `assets/` links), so it renders identically using the existing
stylesheet. The build is repeatable: delete the output folder and re-run.

## Accuracy notes

The Token2 OTP page reflects what the feature actually does, validated on
hardware: a distinct applet from the Yubico/Trussed OATH one (own AID, protocol,
on-device ECDH+AES seed sealing); reachable over CCID/NFC and USB-HID with
auto-detect; supports list / get / add / delete / erase-all / serial / button
HOTP; seeds read from stdin or env (never argv) and zeroized. It omits the
`READ_CONFIG` / `ENABLE_TOTP` / `SET_DEVICE_TYPE` commands that real PIN+
firmware doesn't implement.
