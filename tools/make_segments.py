"""Generates the ring-slice textures the Wheels tab's lists are drawn with:
a slice of a ring around the wheel (inner radius R1, outer R2, half-angle
DELTA), centred in a square texture with the wheel's centre to its left (the
slice points right, outward). The addon turns each one to face the wheel.

  ic_seg_fill.tga  white inside the slice (tinted in game)
  ic_seg_rim.tga   the grey metal rim (dark edges, a lighter bevel)
  ic_seg_glow.tga  a soft outline (tinted gold for the focus)

Run: python3 tools/make_segments.py   (needs Pillow)
"""
import math
import os
from PIL import Image

SIZE = 256            # texture px = UI px in game
R1, R2 = 285, 505     # the slice's inner / outer radius
DELTA = 0.05          # half the slice's angle (radians)
R_MID = (R1 + R2) / 2
SS = 3                # supersampling for smooth edges

RIM = [  # from the outside in: width, (r, g, b, a)
    (1.2, (10, 9, 8, 255)),
    (3.0, (77, 74, 66, 255)),
    (1.0, (118, 112, 100, 235)),
    (1.2, (13, 10, 8, 235)),
]
RIM_W = sum(w for w, _ in RIM)


def distance(x, y):
    """Signed distance into the slice (negative outside), in px."""
    X, Y = x + R_MID, y
    r = math.hypot(X, Y)
    phi = math.atan2(Y, X)
    return min(r - R1, R2 - r, (DELTA - abs(phi)) * r)


def render(shade):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for j in range(SIZE):
        for i in range(SIZE):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sj in range(SS):
                for si in range(SS):
                    x = i + (si + 0.5) / SS - SIZE / 2
                    y = SIZE / 2 - (j + (sj + 0.5) / SS)
                    c = shade(distance(x, y))
                    if c:
                        a = c[3] / 255
                        acc[0] += c[0] * a
                        acc[1] += c[1] * a
                        acc[2] += c[2] * a
                        acc[3] += a
            n = SS * SS
            if acc[3] > 0:
                px[i, j] = (int(acc[0] / acc[3]), int(acc[1] / acc[3]), int(acc[2] / acc[3]),
                            int(255 * acc[3] / n))
    return img


def fill(d):
    return (255, 255, 255, 255) if d >= RIM_W - 0.5 else None


def rim(d):
    if d < 0:
        return None
    edge = 0
    for width, color in RIM:
        if d < edge + width:
            return color
        edge += width
    return None


def glow(d):
    if -3 <= d < 2:
        return (255, 255, 255, int(255 * (1 - abs(d + 0.5) / 3.5)))
    return None


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "textures")
    for name, shade in (("ic_seg_fill", fill), ("ic_seg_rim", rim), ("ic_seg_glow", glow)):
        render(shade).save(os.path.join(out, name + ".tga"))
        print("wrote", name)


if __name__ == "__main__":
    main()
