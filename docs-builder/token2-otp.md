# Token2 on-device OTP

> TOTP and HOTP credentials stored and computed on a Token2 FIDO key's own OTP
> applet — a separate applet from the Yubico/Trussed OATH one, reached over the
> key's CCID/NFC or USB-HID interface.

## What it is

Token2 PIN+ / T2F2 FIDO keys carry a dedicated on-device OTP applet that stores
one-time-password credentials — **TOTP** (time-based, RFC 6238) and **HOTP**
(counter-based, RFC 4226) — directly on the key. As with any hardware OTP, the
seed is shared with the service once at setup; afterward the key computes the
short code on demand from that seed plus the current time or counter. The seed
itself never leaves the key.

This is a **different applet** from the Yubico/Trussed OATH applet. It has its
own application identifier, its own wire protocol, and its own on-device
encryption: each provisioning command seals the seed to the key with an ephemeral
ECDH (P-256) handshake and AES-256-CBC, so the seed is never sent in the clear
even across the local USB or contactless link.

**One applet, two ways in.** The OTP applet answers over both the key's
smart-card (CCID/NFC) interface and its USB-HID interface. Some keys ship with
HID disabled; in that case the applet is still fully usable over CCID. keyroost
auto-detects which interface is live and uses it, or you can force one
explicitly.

## How it compares

- **vs. an authenticator app:** seeds live on tamper-resistant hardware instead
  of a phone backup that can sync to the cloud or be cloned; a credential can
  optionally require a physical button press before it releases a code.
- **vs. the Yubico/Trussed OATH applet:** same TOTP/HOTP standards and the same
  on-hardware benefit, but a Token2-specific applet and protocol. On a Token2
  key this is the native OTP store.
- **vs. FIDO2:** OTP is *not* phishing-resistant — a 6-digit code can be typed
  into a look-alike site and replayed within its window. Prefer FIDO2 where a
  site supports it; use OTP where it only offers "authenticator app" codes.

**Button (keystroke) HOTP.** Beyond the stored credentials, the applet has a
single HOTP-on-button slot: the key types a fresh HOTP code as keystrokes when
touched outside any session (useful for systems such as UserLock). This is
configured separately and is independent of the listed credentials.

## What keyroost does with Token2 OTP

Over the auto-selected transport (CCID/NFC or USB-HID), keyroost can **list**
stored credentials and show live codes, **add** and **delete** them, **erase**
all entries, read the device **serial number**, and configure the **button
HOTP** keystroke slot — all through an in-tree, pure-Rust byte layer (APDU
framing, the ECDH/AES seal, and the variable-length entry parser), with no
vendor SDK.

```
# list stored credentials (auto transport: HID, else CCID/NFC)
keyroostctl otp list

# print the current code for one credential
keyroostctl otp get --app GitHub --account alice

# add a TOTP credential (the Base32 seed is read from stdin, never argv)
"JBSWY3DPEHPK3PXP" | keyroostctl otp add --app GitHub --account alice --seed-stdin

# force a transport, or read the serial
keyroostctl otp --transport ccid list
keyroostctl otp serial
```

In the desktop app, Token2 keys gain an **On-device OTP** tab showing each
credential with a live code and copy / delete actions, an add dialog (issuer,
account, Base32 secret, TOTP/HOTP, SHA-1/SHA-256, digits, period, and an optional
touch requirement), and a transport selector.

**Seeds are handled carefully.** Base32 seeds are taken from stdin or an
environment variable — never command arguments, which would leak into shell
history and process listings — and the in-memory copy is zeroized after use.

## Authoritative resources

- [IETF — RFC 6238 (TOTP)](https://datatracker.ietf.org/doc/html/rfc6238)
- [IETF — RFC 4226 (HOTP)](https://datatracker.ietf.org/doc/html/rfc4226)
- [Token2 — PIN+ / T2F2 FIDO keys](https://www.token2.com/)
