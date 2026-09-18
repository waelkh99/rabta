"""Generate the web icon set from Assets/App Icons/App Icon.png.

Two things the source cannot be used for directly:

  * it sits on a white background rather than transparency, so a favicon made
    from it shows a white box on dark browser chrome;
  * its padding is generous, which is right for a phone home screen and wrong
    at 16px, where the interlocking bubbles close up into a smudge.

So the square is cut out, its corners are masked to transparency, and the small
sizes are cropped tighter than the large ones.

    python tool/make_icons.py
"""

from PIL import Image, ImageDraw

SOURCE = 'Assets/App Icons/App Icon.png'

# How much padding to trim, per size. Measured rather than guessed: at 16 and
# 32 the untrimmed mark is unreadable, and trimming stops helping past ~48.
TRIM = {16: 0.14, 32: 0.12, 48: 0.08}


def squared(img):
    """The rounded square on its own, with transparent corners."""
    # Anything not near-white is the icon; its bounding box is the square.
    rgb = img.convert('RGB')
    mask = rgb.point(lambda v: 0 if v > 245 else 255).convert('L')
    box = mask.getbbox()
    cut = img.crop(box)

    side = min(cut.size)
    cut = cut.crop((0, 0, side, side))

    # The source's own corner radius, so the mask lands on the existing edge
    # instead of cutting a second, tighter curve inside it.
    corners = Image.new('L', cut.size, 0)
    ImageDraw.Draw(corners).rounded_rectangle(
        [(0, 0), (side - 1, side - 1)], radius=int(side * 0.225), fill=255
    )

    out = cut.copy()
    out.putalpha(corners)
    return out


def at(square, size):
    trim = TRIM.get(size, 0.0)
    if trim:
        inset = int(square.width * trim)
        square = square.crop(
            (inset, inset, square.width - inset, square.height - inset)
        )
    return square.resize((size, size), Image.LANCZOS)


def maskable(square, size):
    """Full-bleed, for Android adaptive icons.

    The launcher crops these to whatever shape it likes, so the square has to
    reach every edge and the mark has to stay inside the middle 80%.
    """
    ground = square.convert('RGB').getpixel(
        (int(square.width * 0.12), square.height // 2)
    )
    canvas = Image.new('RGBA', (size, size), ground + (255,))
    inner = square.resize((int(size * 0.78), int(size * 0.78)), Image.LANCZOS)
    offset = (size - inner.width) // 2
    canvas.paste(inner, (offset, offset), inner)
    return canvas


def main():
    square = squared(Image.open(SOURCE).convert('RGBA'))
    print(f'cut the square out of the white ground: {square.size}')

    at(square, 32).save('web/favicon.png')
    for size in (16, 32, 48):
        at(square, size).save(f'web/icons/favicon-{size}.png')
    at(square, 180).save('web/icons/apple-touch-icon.png')

    for size in (192, 512):
        at(square, size).save(f'web/icons/Icon-{size}.png')
        maskable(square, size).save(f'web/icons/Icon-maskable-{size}.png')

    print('wrote favicon, apple touch icon, and the PWA set')


if __name__ == '__main__':
    main()
