#!/usr/bin/env python3
"""Master sprite sheet + Illustrator templates for T's redraw (2026-11-26).

T: "Make a master sheet of sprites for me to redraw from front, I will provide vector
illustrations but I still want you to adjust and put it in the game with pixel stacking
and pixel art".

Outputs (into tools/redraw/):
  master_sprite_sheet.png   every sprite in the game, by where it shows up, with its views,
                            native pixel sizes and slice counts (FRONT marked "start here")
  templates/<name>.svg      one Illustrator/Figma template per asset: the current art on a
                            REFERENCE layer, view boxes + labels on GUIDES, an empty YOUR_ART
                            layer. Coordinates match the 8x view sheet, so tools/import_vector.py
                            can turn the drawing straight into pixel art and a stack.
  manifest.json             names, kinds, view boxes (native px), slices, roles

Run from the project folder:  python3 tools/make_master_sheet.py
"""
import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "art_src"
OUT = ROOT / "tools" / "redraw"
SCALE = 8          # view sheets are drawn at 8x native
LABEL_BAND = 220   # SVG units above the art for labels (outside the import area)

FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_R = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

VIEW_NAMES = ["TOP", "SIDE", "FRONT", "BACK"]
VIEW_HINT = {"TOP": "from above · nose DOWN", "SIDE": "from the left · nose LEFT",
             "FRONT": "nose toward you", "BACK": "tail toward you"}

# name -> (section, role, notes)
STACKS = {
    "jet_player":  ("DOGFIGHT", "Your jet (your concept sheet)", "Grey helmet nose, ONE red cyclops band (it shimmers in game). Seen mostly from behind and above."),
    "jet_fighter": ("DOGFIGHT", "Enemy fighter", "Must read as 'enemy' at 9 px tall: strong silhouette, one loud color."),
    "jet_crimson": ("DOGFIGHT", "Alt player jet (Challenges prize)", "Cosmetic only; same size as your jet."),
    "jet_ghost":   ("DOGFIGHT", "Alt player jet (Challenges prize)", "Cosmetic only; same size as your jet."),
    "kamikaze":    ("DOGFIGHT", "Kamikaze drone", "Dives at you; small. Smoke trail is drawn by the game."),
    "ship":        ("DOGFIGHT", "Flak / artillery ship (ocean)", "Seen from high above; deck detail matters most (TOP view)."),
    "gunship":     ("DOGFIGHT", "QUAD GUNSHIP boss (wave 6)", "Four rotors (weak spots) + belly cannon. Rotor and cannon positions are tied to code: keep them where they are."),
    "palm":        ("DOGFIGHT", "Beach palm (~22 m)", "Leans out to sea. Many on screen at once: keep it simple."),
    "spire":       ("DOGFIGHT", "Mossy sea stack / island spire", "Dark rock + moss tiers (your cove references)."),
    "volcano":     ("DOGFIGHT", "Volcano (erupts in some weather)", "Round: carved as a lathe. Crater on top shows lava glow."),
    "asteroid":    ("DOGFIGHT", "Asteroid (wave 5 impact)", "Round: carved as a lathe. Seen big and close."),
    "hoop":        ("DOGFIGHT", "Speed hoop", "A ring; needs a 2 px gap in the TOP view or the carver fills it."),
    "card_table":  ("CARD ROOM", "Card table (blackjack + hold'em)", "Rim + pedestal. The felt on top is a separate flat texture."),
    "chair":       ("CARD ROOM", "Seat chair (manager seats)", "Seen from the side across the table."),
}
MANAGERS = {'broth': ('Bone Broth Stand', 'Soup Ghoul'), 'xylo': ('Haunted Xylophone Lessons', 'Tone-Deaf Lich'), 'crusher': ('Calcium Crusher', 'Hydraulic Hank'), 'dogpark': ('Totally Legit Dog Park', 'Very Good Boy (CPA)'), 'foundry': ('Femur Foundry', 'Forge Mummy'), 'carwash': ('Ossuary Car Wash', 'Bubbles Moretti'), 'merch': ('Skele-Tees Merch Co.', 'Influencer Wraith'), 'refinery': ('Marrow Refinery', 'Dr. Pith'), 'bank': ('Offshore Bone Bank', 'The Accountant (Deceased)'), 'reactor': ('Ribcage Reactor', 'Chief Containment Ghoul')}   # id -> (building, manager) from scripts/balance.gd
FLATS = [
    ("CARD ROOM · CHARACTERS", "art/table/chars/cadavire_dealer.png", "Cadavire as dealer (dealer suit)", "Stands behind the table; bottom edge = table height."),
] + [("CARD ROOM · CHARACTERS", f"art/table/chars/{n}.png", f"{MANAGERS[n][1]} ({MANAGERS[n][0]})", "Seated at the table end; faces the middle.")
     for n in ["broth", "xylo", "dogpark", "carwash", "crusher", "foundry", "bank", "merch", "refinery", "reactor"]] + [
    ("CARD ROOM · TEXTURES", "art/table/felt.png", "Blackjack felt (GREYSCALE: the game tints it)", "Seen in perspective; text gets squashed, keep it big."),
    ("CARD ROOM · TEXTURES", "art/table/felt_holdem.png", "Hold'em felt (GREYSCALE: tinted)", "Same size as the blackjack felt."),
    ("FX", "art/fx/explosion.png", "Explosion (8 frames, 48 px)", "Left to right, frame 1 = flash."),
    ("FX", "art/fx/explosion_laser.png", "Laser-kill explosion (red)", "Same frame layout."),
    ("FX", "art/fx/explosion_beam.png", "Gunship beam explosion (blue)", "Same frame layout."),
]
CODE_DRAWN = [
    "Play icons (Pool, Dogfight, Blackjack, Hold'em, Pinball, Options): 150 px tiles, scripts/play_icon.gd",
    "Playing cards: 52 faces + back, 120 x 172 px each (128 x 180 cells), scripts/cards/card_art.gd",
    "Cadavire portrait + dialogue art slot: placeholder in the top bar (needs your art, every Fever state)",
    "Sky koi, clouds, rain, lava, lens flares, HUD bars, reticle: drawn by code (style notes welcome)",
]


def view_boxes(sheet: Image.Image):
    """Bounding boxes (x0, y0, x1, y1) in sheet px of the 4 views, left to right."""
    a = np.array(sheet.convert("RGB")).astype(int)
    mask = np.abs(a - np.array([255, 0, 255])).max(axis=2) > 28
    cols = np.where(mask.any(axis=0))[0]
    groups, start, prev = [], cols[0], cols[0]
    for c in cols[1:]:
        if c - prev > SCALE:
            groups.append((start, prev))
            start = c
        prev = c
    groups.append((start, prev))
    boxes = []
    for x0, x1 in groups[:4]:
        rows = np.where(mask[:, x0:x1 + 1].any(axis=1))[0]
        boxes.append((int(x0), int(rows[0]), int(x1) + 1, int(rows[-1]) + 1))
    return boxes


def to_alpha(sheet: Image.Image) -> Image.Image:
    a = np.array(sheet.convert("RGBA"))
    mag = np.abs(a[..., :3].astype(int) - np.array([255, 0, 255])).max(axis=2) <= 28
    a[mag, 3] = 0
    return Image.fromarray(a)


def png_b64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def svg_template(name: str, sheet: Image.Image, boxes, role: str, notes: str, slices: int) -> str:
    W, H = sheet.size
    ref = png_b64(to_alpha(sheet))
    g = []
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        v = VIEW_NAMES[i]
        nw, nh = (x1 - x0) // SCALE, (y1 - y0) // SCALE
        col = "#ffd400" if v == "FRONT" else "#00e5ff"
        g.append(f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" fill="none" stroke="{col}" stroke-width="4" stroke-dasharray="16 10"/>')
        star = "  ★ START HERE" if v == "FRONT" else ""
        g.append(f'<text x="{x0}" y="-120" font-family="Helvetica, Arial" font-weight="bold" font-size="44" fill="{col}">{v}{star}</text>')
        g.append(f'<text x="{x0}" y="-72" font-family="Helvetica, Arial" font-size="30" fill="#ffffff">{VIEW_HINT[v]}</text>')
        g.append(f'<text x="{x0}" y="-34" font-family="Helvetica, Arial" font-size="30" fill="#bbbbbb">{nw} × {nh} px in game</text>')
    title = f'{name} — {role} — {slices} slices'
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Cadavire redraw template: {name}. Draw on YOUR_ART inside the boxes. Do not move or
     resize the artboard. REFERENCE, GUIDES and LABELS are ignored on import.
     Each 8 x 8 units = 1 pixel in game. {notes} -->
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="{W}" height="{H + LABEL_BAND}" viewBox="0 {-LABEL_BAND} {W} {H + LABEL_BAND}">
  <g id="BACKGROUND"><rect x="0" y="{-LABEL_BAND}" width="{W}" height="{H + LABEL_BAND}" fill="#1b1622"/></g>
  <g id="REFERENCE" opacity="0.45"><image x="0" y="0" width="{W}" height="{H}" style="image-rendering:pixelated" xlink:href="data:image/png;base64,{ref}"/></g>
  <g id="GUIDES">{"".join(g)}</g>
  <g id="LABELS"><text x="{W - 20}" y="-170" text-anchor="end" font-family="Helvetica, Arial" font-size="34" fill="#ffffff">{title}</text></g>
  <g id="YOUR_ART"></g>
</svg>
'''


def flat_template(name: str, img: Image.Image, role: str, notes: str) -> str:
    W, H = img.size[0] * SCALE, img.size[1] * SCALE
    ref = png_b64(img.convert("RGBA").resize((W, H), Image.NEAREST))
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Cadavire redraw template: {name} (flat sprite). Draw on YOUR_ART. Do not resize the
     artboard. 8 x 8 units = 1 pixel in game. {notes} -->
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="{W}" height="{H + LABEL_BAND}" viewBox="0 {-LABEL_BAND} {W} {H + LABEL_BAND}">
  <g id="BACKGROUND"><rect x="0" y="{-LABEL_BAND}" width="{W}" height="{H + LABEL_BAND}" fill="#1b1622"/></g>
  <g id="REFERENCE" opacity="0.45"><image x="0" y="0" width="{W}" height="{H}" style="image-rendering:pixelated" xlink:href="data:image/png;base64,{ref}"/></g>
  <g id="GUIDES"><rect x="0" y="0" width="{W}" height="{H}" fill="none" stroke="#ffd400" stroke-width="4" stroke-dasharray="16 10"/></g>
  <g id="LABELS"><text x="0" y="-120" font-family="Helvetica, Arial" font-weight="bold" font-size="44" fill="#ffd400">{name}</text>
    <text x="0" y="-70" font-family="Helvetica, Arial" font-size="30" fill="#ffffff">{role} · {img.size[0]} × {img.size[1]} px in game</text></g>
  <g id="YOUR_ART"></g>
</svg>
'''


# ----------------------------------------------------------------- master PNG
PAGE_W = 2200
BG = (27, 22, 34)
CARD = (40, 33, 50)
TXT = (239, 230, 210)
MUTED = (170, 160, 180)
YEL = (255, 212, 0)
CYAN = (0, 229, 255)


def font(p, s):
    return ImageFont.truetype(p, s)


def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) > width:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def stack_card(name, sheet, boxes, slices, role, notes):
    views = []
    for (x0, y0, x1, y1) in boxes:
        v = to_alpha(sheet.crop((x0, y0, x1, y1)))
        views.append(v.resize(((x1 - x0) // SCALE, (y1 - y0) // SCALE), Image.NEAREST))
    total_w = sum(v.size[0] for v in views)
    slots = sum(max(v.size[0] * 1, 0) for v in views)
    s = max(2, min(10, (PAGE_W - 160 - 3 * 50) // max(1, total_w)))
    while s > 2 and sum(max(v.size[0] * s, 380) for v in views) + 3 * 50 + 80 > PAGE_W - 80:
        s -= 1
    vh = max(v.size[1] for v in views) * s
    h = 150 + vh + 104
    card = Image.new("RGB", (PAGE_W - 80, h), CARD)
    d = ImageDraw.Draw(card)
    d.text((30, 20), name, font=font(FONT_B, 40), fill=TXT)
    d.text((30 + d.textlength(name, font=font(FONT_B, 40)) + 24, 32), f"{role}  ·  {slices} slices (= SIDE height)", font=font(FONT_R, 26), fill=MUTED)
    for i, line in enumerate(wrap(d, notes, font(FONT_R, 24), PAGE_W - 200)[:2]):
        d.text((30, 76 + i * 30), line, font=font(FONT_R, 24), fill=MUTED)
    x = 40
    for i, v in enumerate(views):
        big = v.resize((v.size[0] * s, v.size[1] * s), Image.NEAREST)
        y = 150
        # checker behind the art so dark pixels read
        chk = Image.new("RGB", big.size, (58, 50, 70))
        cd = ImageDraw.Draw(chk)
        for cy in range(0, big.size[1], 2 * s):
            for cx in range(0, big.size[0], 2 * s):
                cd.rectangle([cx, cy, cx + s - 1, cy + s - 1], fill=(66, 58, 80))
                cd.rectangle([cx + s, cy + s, cx + 2 * s - 1, cy + 2 * s - 1], fill=(66, 58, 80))
        card.paste(chk, (x, y))
        card.paste(big, (x, y), big)
        col = YEL if VIEW_NAMES[i] == "FRONT" else CYAN
        d.rectangle([x - 3, y - 3, x + big.size[0] + 2, y + big.size[1] + 2], outline=col, width=3)
        lab = VIEW_NAMES[i] + ("  ★ start here" if VIEW_NAMES[i] == "FRONT" else "")
        d.text((x, y + vh + 12), lab, font=font(FONT_B, 24), fill=col)
        d.text((x, y + vh + 42), f"{v.size[0]} × {v.size[1]} px in game", font=font(FONT_R, 21), fill=TXT)
        d.text((x, y + vh + 70), VIEW_HINT[VIEW_NAMES[i]], font=font(FONT_R, 20), fill=MUTED)
        x += max(big.size[0], 380) + 50
    return card


def flat_card(path, role, notes):
    img = Image.open(ROOT / path).convert("RGBA")
    s = max(1, min(4, 900 // max(img.size)))
    big = img.resize((img.size[0] * s, img.size[1] * s), Image.NEAREST)
    card = Image.new("RGB", (big.size[0] + 60, big.size[1] + 150), CARD)
    d = ImageDraw.Draw(card)
    card.paste(big, (30, 30), big)
    d.text((30, big.size[1] + 42), Path(path).stem, font=font(FONT_B, 26), fill=TXT)
    d.text((30, big.size[1] + 76), f"{img.size[0]}×{img.size[1]} px", font=font(FONT_R, 20), fill=YEL)
    d.text((30, big.size[1] + 104), role[:52], font=font(FONT_R, 20), fill=MUTED)
    return card


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "templates").mkdir(exist_ok=True)
    manifest = {"stacks": {}, "flats": {}}
    blocks = []      # (section, image)
    for name, (section, role, notes) in STACKS.items():
        sheet = Image.open(SRC / f"{name}_views.png").convert("RGBA")
        boxes = view_boxes(sheet)
        slices = json.loads((ROOT / "art" / "stacks" / f"{name}.json").read_text())["slices"]
        manifest["stacks"][name] = {"section": section, "role": role, "slices": slices,
                                    "sheet_size": list(sheet.size),
                                    "views_px": {VIEW_NAMES[i]: [(b[2] - b[0]) // SCALE, (b[3] - b[1]) // SCALE] for i, b in enumerate(boxes)},
                                    "boxes_sheet": boxes}
        (OUT / "templates" / f"{name}.svg").write_text(svg_template(name, sheet, boxes, role, notes, slices))
        blocks.append((section, stack_card(name, sheet, boxes, slices, role, notes)))
    flat_cards = []
    for section, path, role, notes in FLATS:
        if not (ROOT / path).exists():
            continue
        img = Image.open(ROOT / path)
        stem = Path(path).stem
        manifest["flats"][stem] = {"section": section, "path": path, "size": list(img.size), "role": role}
        (OUT / "templates" / f"{stem}.svg").write_text(flat_template(stem, img, role, notes))
        flat_cards.append((section, flat_card(path, role, notes)))
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))

    # ---- compose the page
    parts = []
    hdr = Image.new("RGB", (PAGE_W, 330), BG)
    d = ImageDraw.Draw(hdr)
    d.text((40, 30), "CADAVIRE · MASTER SPRITE SHEET", font=font(FONT_B, 64), fill=TXT)
    lines = [
        "Redraw any of these as vectors (Illustrator / Figma). One SVG template per sprite is in templates/.",
        "Stacked 3D objects need 4 views: TOP (nose down), SIDE (nose left), FRONT, BACK. FRONT is marked ★: start there.",
        "The carver builds the 3D shape from the outlines of TOP + SIDE + FRONT, so every view's outline must agree.",
        "Sizes are in-game pixels: tiny. Your vector gets rendered down to that size, then I clean it up by hand",
        "(palette, outlines, readability) and carve it into a pixel stack. 1 template unit x 8 = 1 game pixel.",
    ]
    for i, l in enumerate(lines):
        d.text((40, 120 + i * 40), l, font=font(FONT_R, 28), fill=MUTED if i else YEL)
    parts.append(hdr)
    cur = None
    for section, img in blocks:
        if section != cur:
            cur = section
            band = Image.new("RGB", (PAGE_W, 110), BG)
            ImageDraw.Draw(band).text((40, 40), f"{section} · PIXEL STACKS", font=font(FONT_B, 46), fill=YEL)
            parts.append(band)
        row = Image.new("RGB", (PAGE_W, img.size[1] + 30), BG)
        row.paste(img, (40, 0))
        parts.append(row)
    # flats in rows
    cur = None
    row_imgs = []

    def flush_row():
        if not row_imgs:
            return
        hh = max(i.size[1] for i in row_imgs)
        row = Image.new("RGB", (PAGE_W, hh + 30), BG)
        x = 40
        for i in row_imgs:
            row.paste(i, (x, 0))
            x += i.size[0] + 24
        parts.append(row)
        row_imgs.clear()

    x_used = 0
    for section, img in flat_cards:
        if section != cur:
            flush_row()
            x_used = 0
            cur = section
            band = Image.new("RGB", (PAGE_W, 110), BG)
            ImageDraw.Draw(band).text((40, 40), f"{section} · FLAT SPRITES", font=font(FONT_B, 46), fill=YEL)
            parts.append(band)
        if x_used + img.size[0] > PAGE_W - 80:
            flush_row()
            x_used = 0
        row_imgs.append(img)
        x_used += img.size[0] + 24
    flush_row()
    foot = Image.new("RGB", (PAGE_W, 110 + 46 * len(CODE_DRAWN) + 40), BG)
    d = ImageDraw.Draw(foot)
    d.text((40, 40), "DRAWN BY CODE (no file yet: send art and I will swap it in)", font=font(FONT_B, 46), fill=YEL)
    for i, l in enumerate(CODE_DRAWN):
        d.text((60, 120 + i * 46), "· " + l, font=font(FONT_R, 28), fill=MUTED)
    parts.append(foot)
    H = sum(p.size[1] for p in parts)
    page = Image.new("RGB", (PAGE_W, H), BG)
    y = 0
    for p in parts:
        page.paste(p, (0, y))
        y += p.size[1]
    page.save(OUT / "master_sprite_sheet.png")
    print(f"master sheet {PAGE_W}x{H}, {len(STACKS)} stacks, {len(manifest['flats'])} flats, templates in {OUT / 'templates'}")


if __name__ == "__main__":
    main()
