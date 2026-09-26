"""Generate the web icon set: the knot from the wordmark, on the night tile.

The mark is the one drawn between "Rabta" and "ربطة" in lib/wordmark.dart —
two overlapping rings, saffron and cream, as the wordmark sits on the dark
panels — so the tab, the home screen and the name are one shape. The geometry
is the widget's: each ring is 62% of the knot's width, the stroke 15%.

Replaced the bubble artwork in Assets/App Icons on 26 September 2026, when the
interface moved to violet and saffron. That file is left where it is.

Drawn, not traced, at 8x and scaled down, so every size is sharp. The small
sizes give the knot more of the tile: at 16px the margin the large icons carry
leaves two rings a few pixels wide.

    python tool/make_icons.py
"""

from PIL import Image, ImageDraw

NIGHT = (0x1D, 0x16, 0x26, 255)
SAFFRON = (0xFF, 0xB4, 0x2E, 255)
CREAM = (0xF6, 0xF0, 0xE6, 255)

SUPER = 8

# How much of the tile's width the knot spans, per size.
SPAN = {16: 0.9, 32: 0.86, 48: 0.82}
DEFAULT_SPAN = 0.72


def knot(draw, cx, cy, width):
    """The two rings, centred on (cx, cy), `width` across."""
    ring = width * 0.62
    stroke = width * 0.15
    left = cx - width / 2
    top = cy - ring / 2
    for x, colour in ((left, SAFFRON), (left + width - ring, CREAM)):
        draw.ellipse(
            [x, top, x + ring, top + ring],
            outline=colour,
            width=round(stroke),
        )


def icon(size, *, rounded=True, span=None):
    big = size * SUPER
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if rounded:
        draw.rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=int(big * 0.225), fill=NIGHT
        )
    else:
        draw.rectangle([0, 0, big, big], fill=NIGHT)
    knot(draw, big / 2, big / 2, big * (span or SPAN.get(size, DEFAULT_SPAN)))
    return img.resize((size, size), Image.LANCZOS)


def main():
    icon(32).save('web/favicon.png')
    for size in (16, 32, 48):
        icon(size).save(f'web/icons/favicon-{size}.png')

    # iOS draws its own rounded corners and fills transparency with black, so
    # the touch icon is a full square.
    icon(180, rounded=False).save('web/icons/apple-touch-icon.png')

    for size in (192, 512):
        icon(size).save(f'web/icons/Icon-{size}.png')
        # Android crops a maskable icon to any shape it likes: full bleed, and
        # the knot inside the middle 80%.
        icon(size, rounded=False, span=0.6).save(
            f'web/icons/Icon-maskable-{size}.png'
        )

    # For the Meta app dashboard, which asks for 1024x1024 and rounds the
    # corners itself. Not served by the site, so it lives with the source art.
    icon(1024, rounded=False).save('Assets/App Icons/meta-app-icon-1024.png')

    print('wrote favicon, apple touch icon, the PWA set, and the Meta app icon')


if __name__ == '__main__':
    main()
