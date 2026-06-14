# Linux Setup

**Quick version:** On Linux, FIDO2/passkeys work out of the box — but the extra
features (PIV, OpenPGP, and On-device OTP) need a one-time setup. Run our setup
script once and you're done.

## Why the setup script?

Your Token2 key talks to the computer in two ways:

- **FIDO2 / passkeys** use a channel Linux already trusts, so this works
  immediately — no setup needed.
- **PIV, OpenPGP, and On-device OTP** use the *smart-card* channel. Linux only
  recognizes a security key as a smart card if its driver (`libccid`) knows that
  specific key model.

Support for current Token2 keys was added in **libccid 1.7.0** (October 2025).
If your system already has that version or newer, the driver knows your key and
those tabs work right away. But stable distributions ship older drivers:

- **Linux Mint, Ubuntu, and Debian** currently include **libccid 1.5.x**, which
  predates Token2 support — so the smart-card tabs stay empty or stuck until the
  driver is taught about your key.

The setup script handles both cases automatically. It installs the smart-card
service, **checks your driver version**, and:

- if your `libccid` is **older than 1.7.0**, it registers your Token2 key with
  the driver so it's recognized;
- if you're already on **1.7.0 or newer**, it skips that step (the key is already
  supported) and just sets up the service and permissions.

Either way, after running it once, every feature works.

## Making files runnable (chmod)

Linux won't run a downloaded file until you mark it as a program. You need to do
this for **both** the AppImage and the setup script.

**Easy way (file manager):** Right-click the file → **Properties** →
**Permissions** tab → tick **"Allow executing file as program"**. Do this for
both files.

**Terminal way:**

```bash
chmod +x token2-linux-setup.sh
chmod +x Token2_Companion_*.AppImage
```

## Putting it together

```bash
chmod +x token2-linux-setup.sh
./token2-linux-setup.sh
```

Then **unplug and replug your key**, and launch the app. All tabs will now work.

> **Already on libccid 1.7.0+?** The script is still safe to run — it just
> confirms the service and permissions and skips the driver step, since your key
> is recognized already.
