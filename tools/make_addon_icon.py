"""The addon's own icon (the AddOns list, ## IconTexture in the toc): the
logo (tools/addon_logo.png: a gamepad's D-pad in an infinity loop, a green
double arrow up) as textures/ic_addon.tga, 128 x 128.

Run: python3 tools/make_addon_icon.py   (needs Pillow)
"""
import os

from PIL import Image

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "addon_logo.png")
OUT = os.path.join(HERE, "..", "ImprovedForever", "textures", "ic_addon.tga")

if __name__ == "__main__":
    Image.open(SRC).convert("RGBA").resize((128, 128), Image.LANCZOS).save(OUT)
    print("wrote", OUT)
