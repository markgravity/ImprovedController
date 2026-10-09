"""The auction window's badge icons: flat white glyphs to sit inside the
small coloured pills (AuctionBuy.lua's badges), tinted by nothing (white on
the pill's colour):
  ic_badge_up      an upgrade: a bold arrow pointing up
  ic_badge_price   a price: a tag with its hole

Drawn 4x and scaled down (smooth edges), 32 x 32, transparent, 32-bit TGA.
Run: python3 tools/make_badge_icons.py   (needs Pillow)
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
SIZE, SCALE = 32, 4
S = SIZE * SCALE
WHITE = (255, 255, 255, 255)


def save(name, draw_fn):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(im))
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(OUT, name + ".tga")
    im.save(path)
    return path


def up(d):
    # A bold arrow: a wide head over a thick stem
    c = S / 2
    d.polygon([(c, S * 0.08), (S * 0.9, S * 0.52), (S * 0.64, S * 0.52), (S * 0.64, S * 0.92),
               (S * 0.36, S * 0.92), (S * 0.36, S * 0.52), (S * 0.1, S * 0.52)], fill=WHITE)


def price(d):
    # A tag leaning right: square body, a point to the left, a hole near it
    body = [(S * 0.38, S * 0.14), (S * 0.9, S * 0.14), (S * 0.9, S * 0.86), (S * 0.38, S * 0.86),
            (S * 0.08, S * 0.5)]
    d.polygon(body, fill=WHITE)
    r = S * 0.08
    hx, hy = S * 0.34, S * 0.5
    d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=(0, 0, 0, 0))


if __name__ == "__main__":
    paths = [save("ic_badge_up", up), save("ic_badge_price", price)]
    # A preview strip on a dark background, scaled up
    strip = Image.new("RGBA", (len(paths) * 96 + 16, 112), (40, 30, 20, 255))
    for i, path in enumerate(paths):
        im = Image.open(path).resize((96, 96), Image.NEAREST)
        strip.alpha_composite(im, (8 + i * 96, 8))
    preview = os.path.join(os.environ.get("TMPDIR", "/tmp"), "badge_icons.png")
    strip.save(preview)
    print("\n".join(paths + [preview]))
