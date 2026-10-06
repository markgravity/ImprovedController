"""The addon's own icon (the AddOns list, ## IconTexture in the toc), in the
radial menu's style (radial_icon.py): a gold gamepad, a green arrow up in
its bottom right corner (improved). textures/ic_addon.tga

Run: python3 tools/make_addon_icon.py [preview.png]   (needs Pillow)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import GOLD, GREEN, STEEL, Icon, preview  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "textures", "ic_addon.tga")
icon = Icon()


def ellipse(d, cx, cy, rx, ry, fill=255):
    pts = [(cx + rx * math.cos(a / 60 * 2 * math.pi), cy + ry * math.sin(a / 60 * 2 * math.pi)) for a in range(60)]
    icon.polygon(d, pts, fill)


def make():
    # The pad: a wide body, two grips hanging down
    body = icon.mask(); d = icon.draw(body)
    ellipse(d, 64, 50, 52, 26)
    icon.polygon(d, [(16, 50), (40, 50), (44, 76), (34, 98), (20, 96), (12, 70)])
    icon.polygon(d, [(112, 50), (88, 50), (84, 76), (94, 98), (108, 96), (116, 70)])
    ellipse(d, 27, 92, 12, 10)
    ellipse(d, 101, 92, 12, 10)

    # Its controls cut in: a D-pad on the left, four buttons on the right
    holes = icon.mask(); d = icon.draw(holes)
    icon.polygon(d, [(28, 38), (36, 38), (36, 46), (44, 46), (44, 54), (36, 54), (36, 62), (28, 62),
                     (28, 54), (20, 54), (20, 46), (28, 46)])
    for x, y in ((96, 38), (104, 48), (88, 48), (96, 58)):
        icon.circle(d, x, y, 4.5)
    pad = icon.cut(body, holes)

    # The sticks, in steel
    sticks = icon.mask(); d = icon.draw(sticks)
    icon.circle(d, 50, 66, 8)
    icon.circle(d, 78, 66, 8)

    # Improved: a green arrow up, bottom right
    arrow = icon.mask(); d = icon.draw(arrow)
    icon.polygon(d, [(98, 72), (122, 98), (108, 98), (108, 122), (88, 122), (88, 98), (74, 98)])

    icon.save(OUT, [(pad, GOLD), (sticks, STEEL), (arrow, GREEN)])


if __name__ == "__main__":
    make()
    if len(sys.argv) > 1:
        preview([OUT], sys.argv[1])
