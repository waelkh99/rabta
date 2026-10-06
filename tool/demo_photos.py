"""Draw the product photos for the demo shop: flat illustrations, no outside
images, so nothing in the demo belongs to anyone else.

    python tool/demo_photos.py

Writes supabase/demo/photos/<name>.jpg at 1200px and <name>_s.jpg at 320px —
the two sizes the app itself stores (lib/services/files.dart) — for
supabase/scripts/demo-shop.mjs to upload.
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path('supabase/demo/photos')
SIZE = 1200
SUPER = 2  # drawn at twice the size and scaled down, for smooth edges

SAND = (245, 240, 232)
SHADOW = (228, 219, 204)


def canvas(ground=SAND):
    img = Image.new('RGB', (SIZE * SUPER, SIZE * SUPER), ground)
    return img, ImageDraw.Draw(img)


def s(*values):
    """Coordinates on the 1200 grid, scaled to the drawing size."""
    return [v * SUPER for v in values]


def shadow(d, cx=600, y=1010, w=380):
    d.ellipse(s(cx - w, y - 34, cx + w, y + 34), fill=SHADOW)


def dress(colour, trim, dots=None):
    img, d = canvas()
    shadow(d)
    # straps and bodice
    d.polygon(s(500, 250, 540, 250, 560, 420, 470, 420), fill=colour)
    d.polygon(s(660, 250, 700, 250, 730, 420, 640, 420), fill=colour)
    d.rounded_rectangle(s(455, 400, 745, 560), radius=40 * SUPER, fill=colour)
    d.rectangle(s(455, 540, 745, 580), fill=trim)
    # skirt
    d.polygon(s(455, 575, 745, 575, 900, 1000, 300, 1000), fill=colour)
    if dots:
        for x, y in [(420, 900), (520, 760), (600, 880), (690, 700), (760, 940), (560, 640), (480, 960), (650, 800)]:
            d.ellipse(s(x - 18, y - 18, x + 18, y + 18), fill=dots)
    return img


def bag(colour, handle, clasp, small=False):
    img, d = canvas()
    shadow(d, w=320 if small else 400)
    if small:
        # The strap leaves the bag's two sides and loops high above it.
        d.arc(s(380, 200, 820, 1000), 180, 360, fill=handle, width=22 * SUPER)
        d.rounded_rectangle(s(380, 520, 820, 980), radius=70 * SUPER, fill=colour)
        d.pieslice(s(380, 380, 820, 820), 180, 360, fill=colour)
        d.rectangle(s(380, 600, 820, 620), fill=handle)
    else:
        d.arc(s(400, 240, 800, 640), 180, 360, fill=handle, width=34 * SUPER)
        d.rounded_rectangle(s(290, 440, 910, 980), radius=60 * SUPER, fill=colour)
        d.rectangle(s(290, 540, 910, 560), fill=handle)
    d.rounded_rectangle(s(565, 560, 635, 630), radius=10 * SUPER, fill=clasp)
    return img


def perfume(glass, liquid, cap):
    img, d = canvas()
    shadow(d, w=260)
    d.rounded_rectangle(s(530, 250, 670, 380), radius=24 * SUPER, fill=cap)
    d.rectangle(s(570, 370, 630, 420), fill=cap)
    d.rounded_rectangle(s(400, 410, 800, 1000), radius=90 * SUPER, fill=glass)
    d.rounded_rectangle(s(440, 560, 760, 960), radius=70 * SUPER, fill=liquid)
    d.rounded_rectangle(s(470, 640, 730, 760), radius=16 * SUPER, fill=(255, 253, 249))
    return img


def heel(colour, sole):
    """A court shoe from the side: one outline, a stiletto, a sole line."""
    img, d = canvas()
    shadow(d, w=380)
    d.polygon(s(230, 940, 250, 860, 420, 800, 560, 825, 700, 700, 830, 585,
                885, 600, 885, 700, 720, 940), fill=colour)
    d.polygon(s(835, 700, 885, 700, 868, 1000, 852, 1000), fill=sole)
    d.rectangle(s(226, 932, 724, 952), fill=sole)
    return img


def scarf(colour, stripe):
    """A folded square, on its corner, with a border and a fringe."""
    img, d = canvas()
    shadow(d, w=320)
    d.polygon(s(600, 250, 950, 600, 600, 950, 250, 600), fill=colour)
    d.polygon(s(600, 330, 870, 600, 600, 870, 330, 600), outline=stripe, width=22 * SUPER)
    d.polygon(s(600, 470, 730, 600, 600, 730, 470, 600), fill=stripe)
    for x in range(555, 650, 22):
        d.line(s(x, 950, x, 1000), fill=colour, width=8 * SUPER)
    return img


def watch(face, strap, rim):
    img, d = canvas()
    shadow(d, w=240)
    d.rounded_rectangle(s(520, 180, 680, 1020), radius=50 * SUPER, fill=strap)
    d.ellipse(s(400, 400, 800, 800), fill=rim)
    d.ellipse(s(440, 440, 760, 760), fill=face)
    d.line(s(600, 600, 600, 480), fill=rim, width=18 * SUPER)
    d.line(s(600, 600, 690, 640), fill=rim, width=14 * SUPER)
    return img


PHOTOS = {
    'evening-dress': lambda: dress((29, 22, 38), (255, 180, 46)),
    'floral-dress': lambda: dress((240, 150, 170), (255, 253, 249), dots=(255, 253, 249)),
    'leather-bag': lambda: bag((139, 90, 43), (92, 56, 30), (218, 180, 110)),
    'crossbody-bag': lambda: bag((91, 22, 200), (60, 14, 140), (255, 180, 46), small=True),
    'rose-perfume': lambda: perfume((250, 214, 222), (230, 120, 150), (201, 162, 90)),
    'oud-perfume': lambda: perfume((210, 170, 110), (120, 60, 20), (40, 30, 30)),
    'red-heels': lambda: heel((200, 40, 60), (70, 20, 30)),
    'silk-scarf': lambda: scarf((11, 122, 110), (255, 180, 46)),
    'gold-watch': lambda: watch((255, 253, 249), (120, 80, 40), (214, 170, 80)),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in PHOTOS.items():
        img = draw().resize((SIZE, SIZE), Image.LANCZOS)
        img.save(OUT / f'{name}.jpg', quality=88)
        img.resize((320, 320), Image.LANCZOS).save(OUT / f'{name}_s.jpg', quality=85)
    print(f'wrote {len(PHOTOS)} photos to {OUT}')


if __name__ == '__main__':
    main()
