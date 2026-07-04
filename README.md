> [!WARNING]
> ## This repository is no longer maintained
>
> **This repository is archived and is no longer maintained or monitored.**
>
> Development has moved upstream to **[framefilter/keyroost](https://github.com/framefilter/keyroost)**, which is now the canonical source for Keyroost and its releases.
>
> - **No new releases** will be published here. Download the latest builds for Windows, macOS, and Linux from the [Keyroost releases page](https://github.com/framefilter/keyroost/releases).
> - **Issues and pull requests are not monitored.** Anything opened here may go unanswered — please use [framefilter/keyroost/issues](https://github.com/framefilter/keyroost/issues) instead.
> - The code here is kept for historical reference only and may be out of date.
>
> Thank you to everyone who used and contributed to this repository.



>Note: This repository exists as a temporary measure to provide faster access to prebuilt binaries. Once the upstream project offers timely releases, this repository will be retired and users will be directed to the official upstream releases instead.



# Token2 Companion rebrand — optional feature patches

These are drop-in replacements for the `rebrand-token2-companion.ps1` /
`rebrand-token2-companion.sh` scripts in the `t2companion-keyroost-builder`
repo, updated so the rebrand can **optionally layer one or more feature
patches** on top of the upstream keyroost checkout before branding.

## What changed

The `-Patch` parameter (PowerShell) / `--patch` flag (shell) now accepts
**multiple patches**, applied in the order given. Passing none (the default)
skips patching, exactly as before — the base OTP feature is already upstream.

- PowerShell: `-Patch` is now an array. `-Patch a.patch,b.patch`
- Shell: `--patch` is now repeatable. `--patch a.patch --patch b.patch`

Each patch is resolved to an absolute path and checked with `git apply --check`
before being applied, so a patch that doesn't fit the chosen base fails loudly
instead of half-applying.

## The two included patches

Both apply cleanly on top of upstream `framefilter/keyroost` main, in this order:

1. **`bio-full.patch`** — fingerprint (CTAP2 bio-enrollment) management:
   CLI commands (`fido-fingerprint-list/-enroll/-rename/-delete`) and the GUI
   Fingerprints card in the Passkeys tab (enroll wizard, rename, delete with
   confirmation, auto-load on unlock). Also includes the CTAPHID keepalive
   timeout fix needed for user-presence operations.
2. **`otp-overview-card.patch`** — adds an On-device OTP card to the Overview
   tab, shown when the key has the OTP applet (matching the Passkeys / PIV /
   OpenPGP cards).

## Usage

PowerShell (Windows):

```powershell
.\rebrand-token2-companion.ps1 `
  -Patch bio-full.patch,otp-overview-card.patch
```

Shell (Linux / macOS):

```bash
./rebrand-token2-companion.sh \
  --patch bio-full.patch \
  --patch otp-overview-card.patch
```

Apply only fingerprints, or only the OTP card, by passing just that one patch.
Pass none to build the plain upstream feature set:

```powershell
.\rebrand-token2-companion.ps1            # no extra features
.\rebrand-token2-companion.ps1 -Patch bio-full.patch   # fingerprints only
```

## Notes

- Order matters only in that both must apply against the same base; the order
  above is verified. If you add more patches later, put the larger/structural
  ones first.
- These patches were built against upstream `main`. If you instead point the
  rebrand at a fork/branch that already contains some of these changes (e.g. a
  branch with the fingerprint work merged), drop the corresponding patch so it
  doesn't conflict.
- The PowerShell script keeps its required UTF-8 BOM and ASCII-only body; don't
  re-save it as UTF-16 or introduce smart quotes/em-dashes, which break the
  parser.
