"""The Binding tab's controller (ic_controller, 512 x 256): a gamepad body in
the panel's dark fill and bronze rim, its shoulders and triggers as
separate pieces above it, and recesses where the D-pad, the face buttons,
the sticks, the touchpad and the small buttons sit. The game's glyphs are
laid over it in game (BindEditor.lua, whose SPOTS match the places here).

Run: python3 tools/make_controller.py   (needs Pillow)
"""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
W, H, SS = 512, 256, 4

FILL = (22, 17, 12, 225)
RIM = (122, 93, 54, 255)
BEVEL = (74, 58, 38, 255)
WELL = (9, 7, 5, 235)
WELL_RIM = (90, 70, 46, 255)


def s(v):
    return [x * SS for x in v]


def mask():
    return Image.new("L", (W * SS, H * SS), 0)


def body():
    m = mask()
    d = ImageDraw.Draw(m)
    d.rounded_rectangle(s((64, 60, 448, 178)), radius=48 * SS, fill=255)
    # The grips: thick round-ended strokes down and out
    for (x1, y1), (x2, y2) in (((118, 132), (100, 206)), ((394, 132), (412, 206))):
        d.line(s((x1, y1, x2, y2)), fill=255, width=80 * SS)
        for x, y in ((x1, y1), (x2, y2)):
            d.ellipse(s((x - 40, y - 40, x + 40, y + 40)), fill=255)
    return m


def piece(box, radius):
    m = mask()
    ImageDraw.Draw(m).rounded_rectangle(s(box), radius=radius * SS, fill=255)
    return m


def erode(m, px):
    return m.filter(ImageFilter.MinFilter(px * 2 * SS + 1)) if px else m


def paint(img, m, fill, rim, bevel=None, width=3):
    """A shape: its fill, a rim `width` wide, a 1 px bevel inside the rim."""
    inner = erode(m, width)
    img.paste(Image.new("RGBA", img.size, fill), (0, 0), inner)
    img.paste(Image.new("RGBA", img.size, rim), (0, 0), ImageChops.subtract(m, inner))
    if bevel:
        img.paste(Image.new("RGBA", img.size, bevel), (0, 0), ImageChops.subtract(inner, erode(m, width + 1)))


def well(img, box, radius, round_=False):
    m = mask()
    d = ImageDraw.Draw(m)
    if round_:
        d.ellipse(s(box), fill=255)
    else:
        d.rounded_rectangle(s(box), radius=radius * SS, fill=255)
    paint(img, m, WELL, WELL_RIM, width=2)


def main():
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    # Triggers, then shoulders, then the body over their lower edges
    for box in ((108, 6, 188, 38), (324, 6, 404, 38)):
        paint(img, piece(box, 14), FILL, RIM, BEVEL)
    for box in ((98, 40, 198, 72), (314, 40, 414, 72)):
        paint(img, piece(box, 12), FILL, RIM, BEVEL)
    paint(img, body(), FILL, RIM, BEVEL)
    # Recesses: D-pad, face buttons, sticks, touchpad, the small buttons
    well(img, (128 - 44, 110 - 44, 128 + 44, 110 + 44), 0, True)
    well(img, (384 - 46, 110 - 46, 384 + 46, 110 + 46), 0, True)
    for x in (196, 316):
        well(img, (x - 30, 158 - 30, x + 30, 158 + 30), 0, True)
    well(img, (206, 68, 306, 124), 10)
    for x in (178, 334):
        well(img, (x - 14, 66, x + 14, 82), 8)
    well(img, (256 - 11, 148 - 11, 256 + 11, 148 + 11), 0, True)
    img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, "ic_controller.tga"))
    print("wrote ic_controller")


if __name__ == "__main__":
    main()
