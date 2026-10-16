#!/usr/bin/env python3
"""Copies QA "tour" captures into docs/screenshots/v5 for the guides, and
builds before/after comparison images.

    python3 tools/export_screenshots.py AFTER_DIR [BEFORE_DIR] [AR_DIR]

AFTER_DIR / BEFORE_DIR / AR_DIR are folders written by
    godot --path game -- --qa=tour --qa-out=DIR [--qa-lang=ar]
Screenshots are resized to 540 px wide JPEGs (quality 86) to keep the repo
and PDFs small.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "screenshots", "v5")

# tour shot -> guide name
MAP = {
    "t01_home_new": "home_new", "t04_home_mid": "home_mid", "t29_home_done": "home_done",
    "t02_levels_new": "levels_new", "t05_levels_mid": "levels_mid",
    "t03_game_tutorial": "game_tutorial", "t06_game_mid": "game_mid", "t07_game_hold": "game_hold",
    "t08_game_p01": "game_p01", "t08_game_f01": "game_f01", "t08_game_k01": "game_k01",
    "t08_game_b01": "game_b01", "t08_game_x05": "game_x05",
    "t09_pause": "pause", "t10_lost": "lost", "t11_win": "win",
    "t12_restore": "restore", "t13_restore_after_unlock": "restore_after_unlock", "t14_restore_choice": "restore_choice",
    "t15_challenges": "challenges", "t16_challenges_scrolled": "challenges_cards",
    "t17_ledger_list": "ledger_list", "t18_ledger_play": "ledger_play", "t19_ledger_rules": "ledger_rules",
    "t20_ledger_hint2": "ledger_hint2", "t21_ledger_won": "ledger_won", "t22_ledger_why": "ledger_why",
    "t23_bakery": "bakery", "t24_bakery_game": "bakery_game",
    "t25_journal_tasks": "journal_tasks", "t25_journal_achievements": "journal_awards", "t25_journal_progress": "journal_progress",
    "t26_settings": "settings", "t26_help": "help", "t26_credits": "credits", "t26_privacy": "privacy", "t26_shop": "shop",
    "t27_story": "story", "t28_exit_dialog": "exit_dialog",
}
PAIRS = ["t04_home_mid", "t05_levels_mid", "t06_game_mid", "t11_win", "t12_restore", "t15_challenges",
         "t17_ledger_list", "t18_ledger_play", "t21_ledger_won", "t25_journal_tasks", "t26_settings", "t16_challenges_scrolled"]


def save(src, dst, w=540):
    im = Image.open(src).convert("RGB")
    im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)
    im.save(dst, "JPEG", quality=86, optimize=True)


def main():
    after = sys.argv[1]
    before = sys.argv[2] if len(sys.argv) > 2 else ""
    ar = sys.argv[3] if len(sys.argv) > 3 else ""
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for k, name in MAP.items():
        p = os.path.join(after, k + ".png")
        if os.path.exists(p):
            save(p, os.path.join(OUT, name + ".jpg"))
            n += 1
    if ar:
        os.makedirs(os.path.join(OUT, "ar"), exist_ok=True)
        for k in ["t04_home_mid", "t05_levels_mid", "t06_game_mid", "t11_win", "t12_restore", "t17_ledger_list",
                  "t18_ledger_play", "t26_settings"]:
            p = os.path.join(ar, k + ".png")
            if os.path.exists(p):
                save(p, os.path.join(OUT, "ar", MAP[k] + ".jpg"))
                n += 1
    if before:
        bd = os.path.join(OUT, "before_after")
        os.makedirs(bd, exist_ok=True)
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
        tiles = []
        for k in PAIRS:
            b = os.path.join(before, k + ".png")
            a = os.path.join(after, k + ".png")
            if not (os.path.exists(a) and os.path.exists(b)):
                continue
            ib = Image.open(b).convert("RGB").resize((360, 640), Image.LANCZOS)
            ia = Image.open(a).convert("RGB").resize((360, 640), Image.LANCZOS)
            pair = Image.new("RGB", (360 * 2 + 24, 640 + 40), "#fbf4e8")
            d = ImageDraw.Draw(pair)
            d.text((8, 8), "Before (v4)", fill="#6b584c", font=font)
            d.text((360 + 24 + 8, 8), "After (v5)", fill="#1f7a72", font=font)
            pair.paste(ib, (0, 40))
            pair.paste(ia, (360 + 24, 40))
            pair.save(os.path.join(bd, MAP[k] + ".jpg"), "JPEG", quality=84, optimize=True)
            tiles.append(pair)
            n += 1
        # one overview sheet
        if tiles:
            cols = 3
            rows = (len(tiles) + cols - 1) // cols
            tw, th = tiles[0].size
            sheet = Image.new("RGB", (cols * tw // 2 + (cols - 1) * 10, rows * th // 2 + (rows - 1) * 10), "#ffffff")
            for i, t in enumerate(tiles):
                t2 = t.resize((tw // 2, th // 2), Image.LANCZOS)
                sheet.paste(t2, ((i % cols) * (tw // 2 + 10), (i // cols) * (th // 2 + 10)))
            sheet.save(os.path.join(bd, "overview.jpg"), "JPEG", quality=82, optimize=True)
    print("exported %d images to %s" % (n, OUT))


if __name__ == "__main__":
    main()
