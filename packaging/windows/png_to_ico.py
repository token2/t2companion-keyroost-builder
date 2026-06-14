#!/usr/bin/env python3
"""png_to_ico.py — convert a PNG to a multi-resolution Windows .ico.

Usage: python png_to_ico.py input.png output.ico

Requires Pillow (`pip install pillow`). Inno Setup's SetupIconFile needs an .ico;
our branding assets are PNG, so this produces an .ico containing the standard
icon sizes from the source image.
"""
import sys

def main():
    if len(sys.argv) != 3:
        print("usage: png_to_ico.py input.png output.ico", file=sys.stderr)
        sys.exit(2)
    src, dst = sys.argv[1], sys.argv[2]
    try:
        from PIL import Image
    except ImportError:
        print("error: Pillow not installed. Run: pip install pillow", file=sys.stderr)
        sys.exit(1)
    img = Image.open(src).convert("RGBA")
    sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    img.save(dst, format="ICO", sizes=sizes)
    print(f"wrote {dst} ({', '.join(f'{w}x{h}' for w, h in sizes)})")

if __name__ == "__main__":
    main()
