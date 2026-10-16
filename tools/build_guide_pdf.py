#!/usr/bin/env python3
"""Builds an illustrated, searchable PDF from one of the repo's Markdown guides.

    python3 tools/build_guide_pdf.py docs/TINY_STREET_PLAYER_GUIDE.md docs/TINY_STREET_PLAYER_GUIDE.pdf

Requires: reportlab, fonttools, pillow (pip install --user reportlab fonttools pillow).
Typeset in the game's own font (Nunito, SIL OFL 1.1; static weights are cut
from game/assets/fonts/Nunito.ttf at build time) with DejaVu Sans as a
fallback for symbols Nunito lacks (★ → ✓ ...).

Supported Markdown (deliberately small): # / ## / ### headings, paragraphs,
- and 1. lists, > callouts, | tables |, ![caption](image) lines (consecutive
image lines form a captioned gallery row), `code`, **bold**, *italic*,
[text](link), --- rules, and <!-- pagebreak -->. The first H1 becomes the
cover title; a line "<!-- subtitle: ... -->" sets the cover subtitle.
"""
import os
import re
import sys
import tempfile

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont as RLTTFont
from reportlab.platypus import (BaseDocTemplate, Frame, Image, KeepTogether, NextPageTemplate, PageBreak,
                                PageTemplate, Paragraph, Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NUNITO = os.path.join(ROOT, "game", "assets", "fonts", "Nunito.ttf")
DEJAVU = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
DEJAVU_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Palette (matches game/src/ui/style.gd)
CREAM = colors.HexColor("#fbf4e8")
LINEN = colors.HexColor("#f7eddc")
PAPER = colors.HexColor("#fffaf3")
EDGE = colors.HexColor("#eadcc6")
INK = colors.HexColor("#3a2a22")
INK_SOFT = colors.HexColor("#6b584c")
TEAL = colors.HexColor("#1f7a72")
TEAL_SOFT = colors.HexColor("#d3ebe6")
CORAL = colors.HexColor("#c95f3f")
GOLD_SOFT = colors.HexColor("#f8e8c4")
NIGHT = colors.HexColor("#161e36")

_cmap = set()


def setup_fonts():
    tmp = tempfile.mkdtemp(prefix="tsfonts")
    for name, w in (("Reg", 500), ("Semi", 650), ("Bold", 800), ("Black", 900)):
        path = os.path.join(tmp, "Nunito-%s.ttf" % name)
        inst = instancer.instantiateVariableFont(TTFont(NUNITO), {"wght": w})
        inst.save(path)
        pdfmetrics.registerFont(RLTTFont("Nunito-" + name, path))
    _cmap.update(TTFont(os.path.join(tmp, "Nunito-Reg.ttf")).getBestCmap().keys())
    pdfmetrics.registerFont(RLTTFont("DejaVu", DEJAVU))
    pdfmetrics.registerFont(RLTTFont("DejaVu-Bold", DEJAVU_B))
    pdfmetrics.registerFontFamily("Nunito", normal="Nunito-Reg", bold="Nunito-Bold", italic="Nunito-Reg", boldItalic="Nunito-Bold")


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def fallback(t):
    """Wrap characters Nunito lacks in the DejaVu font."""
    out = []
    for ch in t:
        if ord(ch) > 127 and ord(ch) not in _cmap:
            out.append('<font name="DejaVu">%s</font>' % ch)
        else:
            out.append(ch)
    return "".join(out)


def inline(t):
    t = esc(t)
    t = re.sub(r"`([^`]+)`", lambda m: '<font name="DejaVu" size="8.6" color="#6b584c">%s</font>' % m.group(1), t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"(?<![\w*])\*([^*\s][^*]*)\*(?!\w)", r"<i>\1</i>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<font color="#165a54"><u>\1</u></font>', t)
    # fallback outside tags only
    parts = re.split(r"(<[^>]+>)", t)
    return "".join(p if p.startswith("<") else fallback(p) for p in parts)


def styles():
    s = {}
    s["body"] = ParagraphStyle("body", fontName="Nunito-Reg", fontSize=10.2, leading=14.6, textColor=INK, spaceAfter=5)
    s["small"] = ParagraphStyle("small", parent=s["body"], fontSize=8.6, leading=11.2, textColor=INK_SOFT)
    s["cell"] = ParagraphStyle("cell", parent=s["body"], fontSize=8.2, leading=10.4, spaceAfter=0)
    s["cellh"] = ParagraphStyle("cellh", parent=s["cell"], fontName="Nunito-Bold", textColor=colors.white)
    s["h1"] = ParagraphStyle("h1", fontName="Nunito-Black", fontSize=21, leading=26, textColor=TEAL, spaceBefore=4, spaceAfter=10, keepWithNext=1)
    s["h2"] = ParagraphStyle("h2", fontName="Nunito-Bold", fontSize=14.5, leading=19, textColor=INK, spaceBefore=12, spaceAfter=6, keepWithNext=1)
    s["h3"] = ParagraphStyle("h3", fontName="Nunito-Bold", fontSize=11.6, leading=15, textColor=TEAL, spaceBefore=8, spaceAfter=4, keepWithNext=1)
    s["bullet"] = ParagraphStyle("bullet", parent=s["body"], leftIndent=13, bulletIndent=3, spaceAfter=2.5)
    s["callout"] = ParagraphStyle("callout", parent=s["body"], fontSize=9.8, leading=13.6, spaceAfter=0)
    s["caption"] = ParagraphStyle("caption", parent=s["small"], alignment=TA_CENTER, fontName="Nunito-Semi", fontSize=8, leading=10)
    s["toc1"] = ParagraphStyle("toc1", fontName="Nunito-Bold", fontSize=10.5, leading=15, textColor=INK, leftIndent=4)
    s["toc2"] = ParagraphStyle("toc2", fontName="Nunito-Reg", fontSize=9.4, leading=12.6, textColor=INK_SOFT, leftIndent=18)
    return s


class Doc(BaseDocTemplate):
    def __init__(self, path, title, **kw):
        super().__init__(path, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=20 * mm,
                         bottomMargin=18 * mm, title=title, author="Tiny Street", **kw)
        self.doc_title = title
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="f")
        self.addPageTemplates([PageTemplate(id="cover", frames=[frame], onPage=self.cover_bg),
                               PageTemplate(id="page", frames=[frame], onPage=self.page_deco)])
        self._seq = 0
        self._last = -1

    def beforeDocument(self):
        # multiBuild runs several passes: keys and outline levels restart each time
        self._seq = 0
        self._last = -1

    def cover_bg(self, c, d):
        w, h = A4
        c.saveState()
        c.setFillColor(CREAM)
        c.rect(0, 0, w, h, fill=1, stroke=0)
        # awning stripes across the top
        n = 14
        sw = w / n
        for i in range(n):
            c.setFillColor(TEAL if i % 2 == 0 else PAPER)
            c.rect(i * sw, h - 34 * mm, sw, 34 * mm, fill=1, stroke=0)
            c.circle(i * sw + sw / 2, h - 34 * mm, sw / 2, fill=1, stroke=0)
        c.setFillColor(LINEN)
        c.rect(0, 0, w, 22 * mm, fill=1, stroke=0)
        c.restoreState()

    def page_deco(self, c, d):
        w, h = A4
        c.saveState()
        c.setFillColor(TEAL)
        c.rect(0, h - 7 * mm, w, 7 * mm, fill=1, stroke=0)
        c.setFont("Nunito-Semi", 8)
        c.setFillColor(INK_SOFT)
        c.drawString(18 * mm, 10 * mm, self.doc_title)
        c.drawRightString(w - 18 * mm, 10 * mm, "Page %d" % d.page)
        c.setStrokeColor(EDGE)
        c.line(18 * mm, 14 * mm, w - 18 * mm, 14 * mm)
        c.restoreState()

    def afterFlowable(self, f):
        if isinstance(f, Paragraph) and getattr(f, "_toc", 0):
            level = min(f._toc - 1, self._last + 1)
            self._last = level
            text = f.getPlainText()
            key = "h%d" % self._seq
            self._seq += 1
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=level, closed=level > 0)
            self.notify("TOCEntry", (level, text, self.page, key))


def image_flow(path, width):
    from PIL import Image as PImage
    with PImage.open(path) as im:
        w, h = im.size
    return Image(path, width=width, height=width * h / w)


def gallery(items, base, s, max_w):
    n = len(items)
    per = min(n, 4 if n >= 4 else n)
    cell_w = (max_w - (per - 1) * 4 * mm) / per
    img_w = min(cell_w, 58 * mm if per <= 2 else cell_w)
    rows = []
    for k in range(0, n, per):
        chunk = items[k:k + per]
        cells = []
        for cap, p in chunk:
            full = os.path.normpath(os.path.join(base, p))
            cells.append([image_flow(full, img_w), Spacer(1, 2), Paragraph(inline(cap), s["caption"])])
        while len(cells) < per:
            cells.append("")
        rows.append(cells)
    t = Table(rows, colWidths=[cell_w] * per, hAlign="CENTER")
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 8), ("LEFTPADDING", (0, 0), (-1, -1), 2),
                           ("RIGHTPADDING", (0, 0), (-1, -1), 2)]))
    return t


def table(rows, s, max_w):
    header = rows[0]
    body = rows[1:]
    ncol = len(header)
    # Every column is at least as wide as its longest word (no letter-by-letter
    # wrapping); the remaining width goes to columns with more text.
    def word_w(t, bold=False):
        plain = re.sub(r"[`*]|\[|\]\([^)]*\)", "", t)
        words = [plain] if len(plain) <= 10 else (plain.split() or [""])
        return max(pdfmetrics.stringWidth(w, "Nunito-Bold" if bold else "Nunito-Reg", 8.2) for w in words) + 10
    mins = []
    for i in range(ncol):
        m = word_w(header[i], True)
        for r in body:
            if i < len(r):
                m = max(m, word_w(r[i]))
        mins.append(min(m, max_w * 0.45))
    lens = [sum(len(r[i]) if i < len(r) else 0 for r in rows) / max(1, len(rows)) for i in range(ncol)]
    spare = max(0.0, max_w - sum(mins))
    tot = sum(lens) or 1.0
    widths = [mins[i] + spare * lens[i] / tot for i in range(ncol)]
    scale = max_w / sum(widths)
    widths = [w * scale for w in widths]
    data = [[Paragraph(inline(c), s["cellh"]) for c in header]]
    for r in body:
        r = r + [""] * (ncol - len(r))
        data.append([Paragraph(inline(c), s["cell"]) for c in r[:ncol]])
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    st = [("BACKGROUND", (0, 0), (-1, 0), TEAL), ("VALIGN", (0, 0), (-1, -1), "TOP"),
          ("LINEBELOW", (0, 0), (-1, -1), 0.4, EDGE), ("BOX", (0, 0), (-1, -1), 0.6, EDGE),
          ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
          ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4)]
    for i in range(1, len(data)):
        if i % 2 == 0:
            st.append(("BACKGROUND", (0, i), (-1, i), LINEN))
    t.setStyle(TableStyle(st))
    return t


def callout(text, s, max_w, kind="note"):
    p = Paragraph(inline(text), s["callout"])
    bg = {"note": TEAL_SOFT, "warn": GOLD_SOFT, "spoiler": colors.HexColor("#f6dccf")}.get(kind, TEAL_SOFT)
    t = Table([[p]], colWidths=[max_w])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), bg), ("LEFTPADDING", (0, 0), (-1, -1), 9),
                           ("RIGHTPADDING", (0, 0), (-1, -1), 9), ("TOPPADDING", (0, 0), (-1, -1), 6),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 7), ("LINEBEFORE", (0, 0), (0, -1), 3, TEAL if kind == "note" else CORAL)]))
    return t


def build(md_path, pdf_path):
    setup_fonts()
    s = styles()
    base = os.path.dirname(os.path.abspath(md_path))
    lines = open(md_path, encoding="utf-8").read().split("\n")
    title = "Tiny Street"
    subtitle = ""
    cover_img = None
    for l in lines:
        if l.startswith("# "):
            title = l[2:].strip()
            break
    m = [l for l in lines if l.startswith("<!-- subtitle:")]
    if m:
        subtitle = m[0][len("<!-- subtitle:"):-3].strip()
    m = [l for l in lines if l.startswith("<!-- cover:")]
    if m:
        cover_img = m[0][len("<!-- cover:"):-3].strip()
    doc = Doc(pdf_path, title)
    max_w = doc.width
    story = []
    # --- cover
    story.append(Spacer(1, 38 * mm))
    story.append(Paragraph(inline(title), ParagraphStyle("ct", fontName="Nunito-Black", fontSize=30, leading=36, textColor=INK, alignment=TA_CENTER)))
    if subtitle:
        story.append(Spacer(1, 4 * mm))
        story.append(Paragraph(inline(subtitle), ParagraphStyle("cs", fontName="Nunito-Semi", fontSize=12.5, leading=17, textColor=INK_SOFT, alignment=TA_CENTER)))
    if cover_img:
        story.append(Spacer(1, 8 * mm))
        imgs = [x.strip() for x in cover_img.split(",")]
        row = [image_flow(os.path.join(base, p), 52 * mm) for p in imgs]
        t = Table([row], colWidths=[56 * mm] * len(row), hAlign="CENTER")
        t.setStyle(TableStyle([("ALIGN", (0, 0), (-1, -1), "CENTER")]))
        story.append(t)
    story.append(NextPageTemplate("page"))
    story.append(PageBreak())
    # --- contents
    story.append(Paragraph("Contents", s["h1"]))
    toc = TableOfContents()
    toc.levelStyles = [s["toc1"], s["toc2"]]
    toc.dotsMinLevel = 0
    story.append(toc)
    story.append(PageBreak())
    # --- body
    i = 0
    seen_h1 = False
    para = []
    imgs = []

    def flush_para():
        if para:
            story.append(Paragraph(inline(" ".join(x.strip() for x in para)), s["body"]))
            para.clear()

    def flush_imgs():
        if imgs:
            story.append(gallery(list(imgs), base, s, max_w))
            imgs.clear()

    while i < len(lines):
        l = lines[i]
        st = l.strip()
        if st.startswith("<!--"):
            flush_para(); flush_imgs()
            if "pagebreak" in st:
                story.append(PageBreak())
            i += 1
            continue
        mimg = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)\s*$", st)
        if mimg:
            flush_para()
            imgs.append((mimg.group(1), mimg.group(2)))
            i += 1
            continue
        flush_imgs()
        if st == "":
            flush_para()
            i += 1
            continue
        if st.startswith("#"):
            flush_para()
            lvl = len(st) - len(st.lstrip("#"))
            text = st[lvl:].strip()
            if lvl == 1 and not seen_h1:
                seen_h1 = True
                i += 1
                continue
            if lvl == 1 and not (story and isinstance(story[-1], PageBreak)):
                story.append(PageBreak())
            p = Paragraph(inline(text), s["h%d" % min(lvl, 3)])
            if lvl <= 2:
                p._toc = lvl
            story.append(p)
            i += 1
            continue
        if st.startswith("|"):
            flush_para()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.match(r"^:?-{2,}:?$", c) for c in cells if c):
                    rows.append(cells)
                i += 1
            story.append(table(rows, s, max_w))
            story.append(Spacer(1, 6))
            continue
        if st.startswith(">"):
            flush_para()
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(lines[i].strip()[1:].strip())
                i += 1
            text = " ".join(buf)
            kind = "note"
            if text.lower().startswith("**spoiler") or text.lower().startswith("**solutions"):
                kind = "spoiler"
            elif text.lower().startswith("**important") or text.lower().startswith("**not run"):
                kind = "warn"
            story.append(callout(text, s, max_w, kind))
            story.append(Spacer(1, 6))
            continue
        mb = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", l)
        if mb:
            flush_para()
            indent = len(mb.group(1)) // 2
            bullet = "•" if mb.group(2) in "-*" else mb.group(2)
            text = mb.group(3)
            # continuation lines
            i += 1
            while i < len(lines) and lines[i].startswith("  ") and lines[i].strip() and not re.match(r"^\s*([-*]|\d+\.)\s", lines[i]):
                text += " " + lines[i].strip()
                i += 1
            stl = ParagraphStyle("b%d" % indent, parent=s["bullet"], leftIndent=13 + indent * 12, bulletIndent=3 + indent * 12)
            story.append(Paragraph(inline(text), stl, bulletText=bullet))
            continue
        if st in ("---", "***"):
            flush_para()
            t = Table([[""]], colWidths=[max_w], rowHeights=[4])
            t.setStyle(TableStyle([("LINEBELOW", (0, 0), (-1, -1), 0.8, EDGE)]))
            story.append(t)
            i += 1
            continue
        para.append(l)
        i += 1
    flush_para()
    flush_imgs()
    doc.multiBuild(story)
    print("wrote", pdf_path)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
