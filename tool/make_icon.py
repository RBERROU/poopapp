"""Génère l'icône Just Fart au style candy-pop (gust 💨 sticker).

Dessine un "gust" de trois gouttes/virgules blanches à contour encre épais sur
un fond dégradé grape -> bubble, façon autocollant. Supersampling x2 pour des
bords nets. Produit :
  assets/icon/icon.png            (1024, fond inclus — iOS + Android legacy + web)
  assets/icon/icon_foreground.png (1024, transparent, marges — Android adaptive)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

# Palette (identique à AppTheme).
GRAPE = (107, 47, 181)
BUBBLE = (255, 79, 163)
ZAP = (255, 210, 63)
INK = (26, 11, 46)
WHITE = (255, 255, 255)

S = 2  # supersampling
SIZE = 1024 * S
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")


def diagonal_gradient(size, c1, c2):
    """Dégradé diagonal c1 (haut-gauche) -> c2 (bas-droite)."""
    base = Image.new("RGB", (size, size))
    px = base.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = (
                int(c1[0] + (c2[0] - c1[0]) * t),
                int(c1[1] + (c2[1] - c1[1]) * t),
                int(c1[2] + (c2[2] - c1[2]) * t),
            )
    return base


def teardrop_mask(size, head_xy, head_r, tail_len):
    """Masque alpha d'une goutte/virgule pointant vers la gauche."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    hx, hy = head_xy
    d.ellipse([hx - head_r, hy - head_r, hx + head_r, hy + head_r], fill=255)
    # Queue triangulaire fusionnée avec la tête, pointe à gauche.
    d.polygon(
        [
            (hx, hy - head_r * 0.72),
            (hx, hy + head_r * 0.72),
            (hx - tail_len, hy),
        ],
        fill=255,
    )
    return m


def gust_mask(size):
    """Masque des trois gouttes formant le 'souffle'."""
    m = Image.new("L", (size, size), 0)
    cx, cy = size * 0.56, size * 0.5
    specs = [
        (( -0.02, -0.18), 0.135, 0.34),
        (( 0.06,  0.02), 0.165, 0.42),
        (( -0.04, 0.22), 0.125, 0.30),
    ]
    for (ox, oy), r, tl in specs:
        drop = teardrop_mask(
            size,
            (cx + ox * size, cy + oy * size),
            r * size,
            tl * size,
        )
        m = Image.composite(Image.new("L", (size, size), 255), m, drop)
    return m


def dilate(mask, radius):
    """Épaissit un masque (pour l'effet contour)."""
    return mask.filter(ImageFilter.MaxFilter(radius * 2 + 1))


def build(with_background=True):
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    if with_background:
        bg = diagonal_gradient(SIZE, GRAPE, BUBBLE).convert("RGBA")
        # Coins arrondis (iOS/web appliquent leur propre masque, mais ça évite
        # les coins carrés sur les surfaces qui ne masquent pas).
        radius = int(SIZE * 0.22)
        rounded = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(rounded).rounded_rectangle(
            [0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255
        )
        canvas.paste(bg, (0, 0), rounded)

    # Le gust : contour encre (masque dilaté) puis remplissage blanc.
    scale = 0.82 if not with_background else 1.0
    gm = gust_mask(SIZE)
    if scale != 1.0:
        small = gm.resize((int(SIZE * scale), int(SIZE * scale)), Image.LANCZOS)
        gm = Image.new("L", (SIZE, SIZE), 0)
        off = (SIZE - small.width) // 2
        gm.paste(small, (off, off))

    outline = dilate(gm, int(SIZE * 0.028))
    ink_layer = Image.new("RGBA", (SIZE, SIZE), INK + (255,))
    canvas = Image.alpha_composite(canvas, Image.composite(
        ink_layer, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), outline))
    white_layer = Image.new("RGBA", (SIZE, SIZE), WHITE + (255,))
    canvas = Image.alpha_composite(canvas, Image.composite(
        white_layer, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), gm))

    return canvas.resize((1024, 1024), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    build(with_background=True).save(os.path.join(OUT_DIR, "icon.png"))
    build(with_background=False).save(os.path.join(OUT_DIR, "icon_foreground.png"))
    print("Icônes générées dans", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
