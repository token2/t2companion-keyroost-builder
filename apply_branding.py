#!/usr/bin/env python3
"""
apply_branding.py — overlay Token2 Companion branding onto a keyroost checkout.

Pure post-checkout source transform. Idempotent-ish: it matches the original
upstream strings, so running twice is harmless (the second run finds nothing to
change). All edits are confined to the `keyroost` GUI crate.

Edits performed:
  * window title + app id            -> the new app name
  * top-bar brand label + tile glyph -> the new app name / "T"
  * accent palette[0]                -> Token2 red (also reorders so red is default)
  * window icon                      -> the embedded T2 mark
  * companion-style header strings   -> "Device Information"-style framing
"""

import argparse
import re
import sys
from pathlib import Path


def patch(path: Path, replacements, required=True):
    """Apply a list of (old, new) literal replacements to a file."""
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in replacements:
        if old not in text:
            if required:
                print(f"  ! pattern not found in {path.name}: {old[:60]!r}", file=sys.stderr)
            continue
        text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"  · patched {path.relative_to(path.parents[3])}")
        return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--app-name", required=True)
    ap.add_argument("--tagline", required=True)
    ap.add_argument("--accent", required=True)         # hex without '#'
    ap.add_argument("--accent-bright", required=True)
    ap.add_argument("--accent-deep", required=True)
    ap.add_argument("--docs-url", default="",
                    help="Base URL for the Learn/docs site (repoints help.rs LEARN_BASE)")
    args = ap.parse_args()

    root = Path(args.root)
    gui = root / "crates" / "keyroost" / "src"
    main_rs = gui / "main.rs"
    theme_rs = gui / "ui" / "theme.rs"

    if not main_rs.exists():
        print(f"error: {main_rs} not found — is --root a keyroost checkout?", file=sys.stderr)
        sys.exit(1)

    name = args.app_name
    r = int(args.accent[0:2], 16)
    g = int(args.accent[2:4], 16)
    b = int(args.accent[4:6], 16)

    # --- main.rs: window title, app id, brand label, tile glyph --------------
    patch(main_rs, [
        ('.with_title("keyroost"),', f'.with_title("{name}"),'),
        ('eframe::run_native(\n        "keyroost",',
         f'eframe::run_native(\n        "{name}",'),
        ('egui::RichText::new("keyroost")',
         f'egui::RichText::new("{name}")'),
        ("glyph_tile(ui, 26.0, p.brand, p.accent_ink, Some('k'));",
         "glyph_tile(ui, 26.0, p.brand, p.accent_ink, Some('T'));"),
    ])

    # --- main.rs: install the window icon ------------------------------------
    # Add an icon to the ViewportBuilder. We load the PNG bytes at runtime from
    # the asset dir the shell script materialized.
    icon_load = (
        '.with_title("' + name + '"),\n'
    )
    icon_block = (
        '.with_title("' + name + '")\n'
        '            .with_icon(load_app_icon()),\n'
    )
    # Replace the (already-renamed) title line to also set the icon.
    if main_rs.read_text(encoding="utf-8").count('.with_title("' + name + '"),') == 1:
        patch(main_rs, [(icon_load, icon_block)])

        # Add the loader fn just before `fn main(`.
        loader_fn = (
            'fn load_app_icon() -> egui::IconData {\n'
            '    // Window/taskbar icon (Token2 "T2" mark), decoded from the PNG\n'
            '    // shipped in assets/branding by the rebrand script.\n'
            '    let bytes = include_bytes!("../assets/branding/app-icon.png");\n'
            '    match image::load_from_memory(bytes) {\n'
            '        Ok(img) => {\n'
            '            let img = img.to_rgba8();\n'
            '            let (w, h) = img.dimensions();\n'
            '            egui::IconData { rgba: img.into_raw(), width: w, height: h }\n'
            '        }\n'
            '        Err(_) => egui::IconData { rgba: vec![0; 4], width: 1, height: 1 },\n'
            '    }\n'
            '}\n\n'
        )
        text = main_rs.read_text(encoding="utf-8")
        if "fn load_app_icon()" not in text:
            text = text.replace("fn main()", loader_fn + "fn main()", 1)
            main_rs.write_text(text, encoding="utf-8")
            print("  · added load_app_icon()")

    # --- theme.rs: make Token2 red the default accent ------------------------
    patch(theme_rs, [
        (
            "    pub const ACCENTS: [Color32; 3] = [\n"
            "        Color32::from_rgb(0x4f, 0x90, 0xff), // blue (default)\n"
            "        Color32::from_rgb(0x2b, 0xb3, 0xa3), // teal\n"
            "        Color32::from_rgb(0x8b, 0x7c, 0xf0), // violet\n"
            "    ];",
            "    pub const ACCENTS: [Color32; 3] = [\n"
            f"        Color32::from_rgb(0x{r:02x}, 0x{g:02x}, 0x{b:02x}), // Token2 red (default)\n"
            "        Color32::from_rgb(0x4f, 0x90, 0xff), // blue\n"
            "        Color32::from_rgb(0x2b, 0xb3, 0xa3), // teal\n"
            "    ];",
        ),
    ])

    # --- main.rs: default to the light theme (Token2 Companion is light) -----
    # Respect an explicitly saved choice, but make Light the default when no
    # preference is stored (or it's unrecognized).
    patch(main_rs, [
        (
            '                    let mode = if s.get_string("mode").as_deref() == Some("light") {\n'
            '                        Mode::Light\n'
            '                    } else {\n'
            '                        Mode::Dark\n'
            '                    };',
            '                    let mode = if s.get_string("mode").as_deref() == Some("dark") {\n'
            '                        Mode::Dark\n'
            '                    } else {\n'
            '                        Mode::Light\n'
            '                    };',
        ),
        (
            '                .unwrap_or((Mode::Dark, 0, false));',
            '                .unwrap_or((Mode::Light, 0, false));',
        ),
    ])

    # --- device.rs: show the OTP tab for Token2 keys seen over CCID ----------
    # Upstream only sets Caps::OTP in the USB-HID enumeration path (gated on VID
    # 0x349E). A Token2 key presented over CCID/NFC (HID disabled, or contactless)
    # therefore loses its On-device OTP tab. Add the capability in the PC/SC build
    # too, when the reader name identifies a Token2 device.
    device_rs = gui / "ui" / "device.rs"
    if device_rs.exists():
        patch(device_rs, [
            (
                "        if p.has_piv {\n"
                "            caps.insert(Caps::PIV);\n"
                "        }\n",
                "        if p.has_piv {\n"
                "            caps.insert(Caps::PIV);\n"
                "        }\n"
                "        // Token2 keys carry the on-device OTP applet, reachable over CCID/NFC\n"
                "        // as well as HID. Offer the OTP tab when the reader is a Token2.\n"
                "        if p.reader_name.to_ascii_lowercase().contains(\"token2\") {\n"
                "            caps.insert(Caps::OTP);\n"
                "        }\n",
            ),
        ], required=False)

    # --- keyroost Cargo.toml: ensure `image` dep for icon decoding -----------
    cargo = root / "crates" / "keyroost" / "Cargo.toml"
    ctext = cargo.read_text(encoding="utf-8")
    if "\nimage " not in ctext and 'image =' not in ctext:
        # insert under [dependencies]
        ctext = ctext.replace(
            "[dependencies]",
            '[dependencies]\nimage = { version = "0.25", default-features = false, features = ["png"] }',
            1,
        )
        cargo.write_text(ctext, encoding="utf-8")
        print("  · added `image` dependency for icon decoding")

    # --- companion-style framing: rename the Overview tab to match the app ---
    # The Token2 Companion App calls its landing screen "Device Information".
    patch(main_rs, [
        ('CapTab::Overview => "Overview",',
         'CapTab::Overview => "Device Information",'),
    ], required=False)

    # --- help.rs: repoint the documentation base URL ------------------------
    # keyroost routes every "Learn" link and every "?" popover through a single
    # LEARN_BASE constant. Swapping it repoints all documentation links at once.
    if args.docs_url:
        help_rs = gui / "ui" / "help.rs"
        if help_rs.exists():
            htext = help_rs.read_text(encoding="utf-8")
            new_url = args.docs_url.rstrip("/")
            # Replace whatever string literal LEARN_BASE is currently set to.
            m = re.search(r'pub const LEARN_BASE: &str = "([^"]*)";', htext)
            if m:
                htext = htext.replace(
                    f'pub const LEARN_BASE: &str = "{m.group(1)}";',
                    f'pub const LEARN_BASE: &str = "{new_url}";',
                )
                help_rs.write_text(htext, encoding="utf-8")
                print(f"  · repointed docs base URL -> {new_url}")
            else:
                print("  ! LEARN_BASE not found in help.rs (skipped docs repoint)",
                      file=sys.stderr)
        else:
            print("  ! help.rs not found (skipped docs repoint)", file=sys.stderr)

    print("branding overlay complete.")


if __name__ == "__main__":
    main()
