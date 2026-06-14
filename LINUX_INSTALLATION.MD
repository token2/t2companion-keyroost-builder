# Linux Setup
 
**Quick version:** On Linux, FIDO2/passkeys work out of the box — but the extra
features (PIV, OpenPGP, and On-device OTP) need a one-time setup. Run our setup
script once and you're done.
 
## Why the setup script?
 
Your Token2 key talks to the computer in two ways:
 
- **FIDO2 / passkeys** use a channel Linux already trusts, so this works
  immediately — no setup needed.
- **PIV, OpenPGP, and On-device OTP** use the *smart-card* channel. Linux only
  recognizes a security key as a smart card if its driver knows that specific key
  model. On Linux Mint, Ubuntu, and Debian, the installed driver is a bit older
  than your Token2 key, so it doesn't recognize it yet — which is why those tabs
  stay empty or stuck.
The setup script fixes this: it installs the smart-card service, teaches the
driver about your Token2 key, and grants your user permission to access it — all
automatically. After running it once, every feature works.
 
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
